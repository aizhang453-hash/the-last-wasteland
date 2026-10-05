"""
最后的废土 · 战斗练习场
一小块空地, 你和两个强盗, 用来试战斗规则。
运行方法: 在终端里进入游戏文件夹 (the-last-wasteland), 输入 python3 arena.py
"""

import os

os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")  # 不在终端里打印 pygame 的欢迎语

import pygame

from game import screen


def main():
    # 只开画面和字体, 不开声音 (现在还没有声音)
    pygame.display.init()
    pygame.font.init()
    try:
        # 窗口可以拉大拉小, 画面跟着放大缩小
        window = pygame.display.set_mode((screen.W, screen.H), pygame.SCALED | pygame.RESIZABLE)
    except pygame.error:
        window = pygame.display.set_mode((screen.W, screen.H))
    pygame.display.set_caption("最后的废土 · 战斗练习场")
    arena = screen.Arena()
    clock = pygame.time.Clock()
    while arena.running:
        dt = clock.tick(60) / 1000
        for event in pygame.event.get():
            arena.handle(event)
        arena.update(dt)
        arena.draw(window)
        pygame.display.flip()
    pygame.quit()


if __name__ == "__main__":
    main()
