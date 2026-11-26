# creative_assets.rb — upload the iOS 27 App Store creative assets (product page
# header, search results art) to the app's Asset Library and place them on the
# editable version's en-US localization, through the App Store Connect API
# (Asset Library endpoints, API 4.5+). Spaceship has no wrapper for these yet, so
# this talks to the REST API directly with the token Spaceship already holds.
#
# Idempotent: each image's referenceName carries the file's MD5, so a placement
# whose image already matches the local file is left alone. A changed file gets
# a new image and placement; the old placement is removed and the old image is
# deleted (or archived, if it has gone past Prepare for Submission).
#
# Placing an asset on a version means it goes to App Review with that version's
# submission; nothing here submits anything.

require "digest/md5"
require "json"
require "net/http"

module CreativeAssets
  API = "https://api.appstoreconnect.apple.com/"
  GROUP = "DEFAULT_PROFILE" # the only profile group for header / search results

  module_function

  def api(method, path, body = nil)
    uri = URI(path.start_with?("http") ? path : API + path)
    req = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
    req["Authorization"] = "Bearer #{Spaceship::ConnectAPI.token.text}"
    req["Content-Type"] = "application/json"
    req.body = body.to_json if body
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
    unless res.code.start_with?("2")
      raise "App Store Connect #{method.upcase} #{uri.path} -> #{res.code}: #{res.body.to_s[0, 600]}"
    end
    res.body.to_s.empty? ? {} : JSON.parse(res.body)
  end

  # jobs: [{ file:, placement_type:, label: }]. Returns one result hash per job.
  def sync!(app_id:, version_id:, jobs:, ui:)
    library_id = api(:get, "v1/apps/#{app_id}/assetLibrary")["data"]["id"]
    loc = api(:get, "v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations")["data"]
          .find { |l| l["attributes"]["locale"] == "en-US" } or raise "No en-US localization on the version"

    jobs.map do |job|
      bytes = File.binread(job[:file])
      md5 = Digest::MD5.hexdigest(bytes)
      reference = "#{job[:label]} #{md5[0, 12]}"
      current = placements(loc["id"]).select { |p| p["attributes"]["placementType"] == job[:placement_type] }
      if current.any? { |p| placement_image(p)&.dig("attributes", "referenceName") == reference }
        ui.message("#{File.basename(job[:file])}: already placed (#{md5[0, 12]}), skipping")
        next verify(loc["id"], job, reference)
      end

      image = reusable_image(library_id, reference, ui) || upload_image(library_id, job[:file], bytes, reference, ui)
      current.each { |p| retire(p, ui) }
      api(:post, "v1/appAssetLibraryPlacements", { data: {
        type: "appAssetLibraryPlacements",
        attributes: { placementType: job[:placement_type], placementGroup: GROUP },
        relationships: {
          image: { data: { type: "appAssetLibraryImages", id: image["id"] } },
          appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: loc["id"] } }
        }
      } })
      verify(loc["id"], job, reference)
    end
  end

  def placements(localization_id)
    res = api(:get, "v1/appStoreVersionLocalizations/#{localization_id}/placements?limit=50")
    res["data"] || []
  end

  def placement_image(placement)
    api(:get, "v1/appAssetLibraryPlacements/#{placement['id']}?include=image")["included"]&.first
  end

  # An earlier run may have uploaded this exact file and then failed before placing it.
  # Reference names are unique per library, so reuse that image instead of uploading again.
  def reusable_image(library_id, reference, ui)
    images = api(:get, "v1/appAssetLibraries/#{library_id}/images?limit=200")["data"] || []
    found = images.find { |i| i.dig("attributes", "referenceName") == reference }
    return nil unless found
    if %w[AWAITING_UPLOAD FAILED].include?(found.dig("attributes", "state"))
      api(:delete, "v1/appAssetLibraryImages/#{found['id']}")
      return nil
    end
    ui.message("#{reference}: reusing unplaced image #{found['id']}")
    found
  end

  def upload_image(library_id, path, bytes, reference, ui)
    image = api(:post, "v1/appAssetLibraryImages", { data: {
      type: "appAssetLibraryImages",
      attributes: { category: "CREATIVE_ASSETS", fileName: File.basename(path),
                    fileSize: bytes.bytesize, referenceName: reference },
      relationships: { assetLibrary: { data: { type: "appAssetLibraries", id: library_id } } }
    } })["data"]
    (image["attributes"]["uploadOperations"] || []).each do |op|
      uri = URI(op["url"])
      req = Net::HTTP.const_get(op["method"].capitalize).new(uri)
      (op["requestHeaders"] || []).each { |h| req[h["name"]] = h["value"] }
      req.body = bytes.byteslice(op["offset"], op["length"])
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
      raise "Upload part for #{File.basename(path)} failed: #{res.code}" unless res.code.start_with?("2")
    end
    api(:patch, "v1/appAssetLibraryImages/#{image['id']}",
        { data: { type: "appAssetLibraryImages", id: image["id"], attributes: { uploaded: true } } })

    state = nil
    60.times do
      attrs = api(:get, "v1/appAssetLibraryImages/#{image['id']}")["data"]["attributes"]
      state = attrs["state"]
      raise "#{File.basename(path)} failed processing: #{attrs['stateDetails']}" if state == "FAILED"
      break unless %w[AWAITING_UPLOAD UPLOAD_COMPLETE].include?(state)
      sleep 5
    end
    ui.message("#{File.basename(path)}: uploaded as #{image['id']} (#{state})")
    image
  end

  # Remove a superseded placement, then delete its image (or archive it once it
  # has left Prepare for Submission, where deletion is no longer allowed).
  def retire(placement, ui)
    image = placement_image(placement)
    api(:delete, "v1/appAssetLibraryPlacements/#{placement['id']}")
    return unless image
    deleted = false
    if image.dig("attributes", "state") == "PREPARE_FOR_SUBMISSION"
      begin
        api(:delete, "v1/appAssetLibraryImages/#{image['id']}")
        deleted = true
      rescue RuntimeError => e
        # An image that went out with a (since cancelled) review keeps PREPARE_FOR_SUBMISSION
        # but can no longer be deleted; archive it like any submitted image.
        raise unless e.message.include?("ASSET_PREVIOUSLY_SUBMITTED_FOR_REVIEW")
      end
    end
    unless deleted
      begin
        api(:patch, "v1/appAssetLibraryImages/#{image['id']}",
            { data: { type: "appAssetLibraryImages", id: image["id"], attributes: { archived: true } } })
      rescue RuntimeError => e
        # Submitted but never approved (review cancelled): Apple allows neither delete nor
        # archive. It stays unplaced in the library, which is harmless.
        raise unless e.message.include?("Only an approved asset can be archived")
        ui.important("Left unplaced image #{image['id']} in the library (submitted, never approved)")
      end
    end
    ui.message("Retired the previous #{placement.dig('attributes', 'placementType')} image #{image['id']}")
  end

  # Fresh re-query: exactly one placement of this type, on an image that matches.
  def verify(localization_id, job, reference)
    mine = placements(localization_id).select { |p| p["attributes"]["placementType"] == job[:placement_type] }
    image = mine.size == 1 ? placement_image(mine.first) : nil
    ok = image && image.dig("attributes", "referenceName") == reference
    size = image&.dig("attributes", "imageAsset")&.values_at("width", "height")&.join("x")
    { file: File.basename(job[:file]), placement: job[:placement_type], count: mine.size,
      image_state: image&.dig("attributes", "state"), size: size, ok: !!ok }
  end
end
