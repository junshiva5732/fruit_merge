"""Google Play 스토어 등록용 이미지 생성 (ko / en).
실행: python tool/make_store_assets.py [ko|en ...]   (인자 없으면 모두)
입력: assets/icon/icon.png, store/raw/<lang>/s_*.png (에뮬레이터 720x1280, tool/capture_screens.sh)
출력: store/icon-512.png, store/<lang>/feature-graphic.png, store/<lang>/screenshots/NN.png (1080x1920)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
STORE = os.path.join(ROOT, "store")
RAW = os.path.join(STORE, "raw")

# 게임 배경과 같은 살구 → 주황 그라데이션 + 초록 포인트
TOP = (255, 183, 77)
BOTTOM = (244, 81, 30)
CREAM = (255, 255, 255)
ACCENT = (255, 241, 118)

LANGS = {
    "ko": {
        "bold": r"C:\Windows\Fonts\malgunbd.ttf",
        "reg": r"C:\Windows\Fonts\malgun.ttf",
        "title": "과일 합치기",
        "tagline": "합치고 합쳐서 수박까지!",
        "sub": "물리 머지 퍼즐 · 스테이지 60개 · 무한 모드",
        "shots": [
            ("s_game.png", "같은 과일이 닿으면", "다음 과일로 합체!"),
            ("s_map.png", "6개 지역을 여행하는", "스테이지 60개"),
            ("s_intro.png", "목표를 달성하고", "별 3개에 도전"),
            ("s_help.png", "무지개 · 폭탄 · 돌", "특수 과일과 콤보 ×5"),
            ("s_share.png", "점수 카드로 자랑하고", "친구에게 도전장!"),
        ],
    },
    "en": {
        "bold": r"C:\Windows\Fonts\segoeuib.ttf",
        "reg": r"C:\Windows\Fonts\segoeui.ttf",
        "title": "Fruit Merge",
        "tagline": "Merge your way to a watermelon!",
        "sub": "Physics puzzle  ·  60 stages  ·  Endless mode",
        "shots": [
            ("s_game.png", "Same fruits touch,", "they merge into the next!"),
            ("s_map.png", "Travel 6 regions with", "60 stages"),
            ("s_intro.png", "Clear the goals and", "earn 3 stars"),
            ("s_help.png", "Rainbow, bombs & stones", "plus up to x5 combos"),
            ("s_share.png", "Share your score card", "and challenge friends!"),
        ],
    },
}


def font(path, size):
    return ImageFont.truetype(path, size)


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            k = (y / max(h - 1, 1)) * 0.65 + (x / max(w - 1, 1)) * 0.35
            px[x, y] = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * k) for i in range(3))
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def shadow(base, box_size, pos, radius, blur=40, alpha=110):
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer = Image.new("RGBA", box_size, (0, 0, 0, alpha))
    sh.paste(layer, (pos[0], pos[1] + 24), rounded_mask(box_size, radius))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(sh)


def fit_font(draw, text, path, size, max_w):
    """max_w 를 넘지 않도록 폰트 크기를 줄인다."""
    while size > 20:
        f = font(path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 2
    return font(path, size)


# ---------------------------------------------------------------- 512 아이콘 (언어 공통)
icon = Image.open(os.path.join(ROOT, "assets", "icon", "icon.png")).convert("RGB")
icon.resize((512, 512), Image.LANCZOS).save(os.path.join(STORE, "icon-512.png"))


def build(lang):
    L = LANGS[lang]
    out = os.path.join(STORE, lang)
    shots_dir = os.path.join(out, "screenshots")
    os.makedirs(shots_dir, exist_ok=True)
    raw = os.path.join(RAW, lang)

    # ------------------------------------------------------------ 피처 그래픽 1024x500
    W, H = 1024, 500
    fg = gradient(W, H).convert("RGBA")
    isz = 300
    ic = icon.resize((isz, isz), Image.LANCZOS).convert("RGBA")
    ipos = (90, (H - isz) // 2)
    shadow(fg, (isz, isz), ipos, 64)
    fg.paste(ic, ipos, rounded_mask((isz, isz), 64))

    d = ImageDraw.Draw(fg)
    tx = 450
    d.text((tx, 92), L["title"], font=fit_font(d, L["title"], L["bold"], 110, W - tx - 40), fill=CREAM)
    d.text((tx + 4, 258), L["tagline"], font=fit_font(d, L["tagline"], L["bold"], 40, W - tx - 40), fill=ACCENT)
    d.text((tx + 4, 318), L["sub"], font=fit_font(d, L["sub"], L["reg"], 28, W - tx - 40), fill=(255, 243, 224))
    fg.convert("RGB").save(os.path.join(out, "feature-graphic.png"))

    # ------------------------------------------------------------ 스크린샷 1080x1920
    SW, SH = 1080, 1920
    for n, (fname, line1, line2) in enumerate(L["shots"], start=1):
        bg = gradient(SW, SH).convert("RGBA")
        d = ImageDraw.Draw(bg)

        # 상단 캡션
        for text, path, size, y, col in ((line1, L["reg"], 58, 150, CREAM), (line2, L["bold"], 76, 230, ACCENT)):
            f = fit_font(d, text, path, size, SW - 120)
            w = d.textlength(text, font=f)
            d.text(((SW - w) / 2, y), text, font=f, fill=col)

        # 폰 스크린샷 (상태바와 하단 테스트 배너·내비 바 잘라내고 둥근 모서리)
        src = Image.open(os.path.join(raw, fname)).convert("RGBA")
        src = src.crop((0, 48, src.width, 1120))  # 상태바 / 하단 테스트 배너·내비 바 제거
        ph = SH - 420
        pw = int(src.width * ph / src.height)
        src = src.resize((pw, ph), Image.LANCZOS)
        ppos = ((SW - pw) // 2, 380)
        shadow(bg, (pw, ph), ppos, 48)
        border = Image.new("RGBA", (pw + 16, ph + 16), (255, 255, 255, 60))
        bg.paste(border, (ppos[0] - 8, ppos[1] - 8), rounded_mask((pw + 16, ph + 16), 56))
        bg.paste(src, ppos, rounded_mask((pw, ph), 48))

        bg.convert("RGB").save(os.path.join(shots_dir, f"{n:02d}.png"))
    print("done:", os.path.abspath(out))


for lang in (sys.argv[1:] or LANGS):
    build(lang)
