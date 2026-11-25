"""Create a merged 0x0 factory binary after PlatformIO builds firmware.bin."""
from os.path import join
import subprocess

Import("env")


def merge_bin(source, target, env):
    platform = env.PioPlatform()
    esptool_dir = platform.get_package_dir("tool-esptool")
    if esptool_dir:
        esptool_cmd = [join(esptool_dir, "esptool")]
    else:
        esptool_cmd = [env.subst("$PYTHONEXE"), "-m", "esptool"]

    board = env.BoardConfig()
    flash_mode = env.subst("${__get_board_flash_mode(__env__)}") or board.get("build.flash_mode", "dio")
    flash_freq = env.subst("${__get_board_f_image(__env__)}") or "80m"
    flash_size = board.get("upload.flash_size", "keep")
    app_offset = env.subst("$ESP32_APP_OFFSET") or "0x10000"

    out_path = env.subst("$BUILD_DIR/firmware-merged.bin")
    cmd = [
        *esptool_cmd,
        "--chip",
        board.get("build.mcu", "esp32s3"),
        "merge-bin",
        "-o",
        out_path,
        "--flash-mode",
        flash_mode,
        "--flash-freq",
        flash_freq,
        "--flash-size",
        flash_size,
    ]
    for offset, img_path in env.get("FLASH_EXTRA_IMAGES", []):
        cmd.extend([str(offset), env.subst(str(img_path))])
    cmd.extend([app_offset, str(target[0])])

    print(f"Merging factory firmware image -> {out_path}")
    subprocess.run(cmd, check=True)


env.AddPostAction("$BUILD_DIR/${PROGNAME}.bin", merge_bin)
