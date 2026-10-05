"""
找能显示中文的字体。用电脑自带的字体 (不放别人的字体文件进仓库), Mac 和 Windows 都试一遍。
"""

import os

import pygame

_WINDOWS_FONTS = os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts")

CANDIDATES = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",  # Mac: 冬青黑体
    "/System/Library/Fonts/STHeiti Medium.ttc",    # Mac: 华文黑体
    "/System/Library/Fonts/PingFang.ttc",          # Mac: 苹方 (有的版本在这里)
    "/Library/Fonts/Arial Unicode.ttf",
    os.path.join(_WINDOWS_FONTS, "msyh.ttc"),      # Windows: 微软雅黑
    os.path.join(_WINDOWS_FONTS, "simhei.ttf"),    # Windows: 黑体
    os.path.join(_WINDOWS_FONTS, "simsun.ttc"),    # Windows: 宋体
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",  # Linux
]
NAMES = ["microsoftyahei", "pingfangsc", "hiraginosansgb", "stheiti", "simhei",
         "notosanscjksc", "wenquanyimicrohei"]

_path = None
_cache = {}


def find_font():
    """找到的字体文件路径; 一个都找不到返回 None (那样中文会显示成方块)"""
    global _path
    if _path is None:
        _path = next((p for p in CANDIDATES if os.path.exists(p)), None) or pygame.font.match_font(NAMES) or ""
    return _path or None


def get(size):
    """某个大小的字体 (同样大小只读一次)"""
    if size not in _cache:
        _cache[size] = pygame.font.Font(find_font(), size)
    return _cache[size]
