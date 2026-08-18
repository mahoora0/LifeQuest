from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".cache"
OUT = ROOT / "demo-output" / "frames"
OUT.mkdir(parents=True, exist_ok=True)

FONT = Path(r"C:\Windows\Fonts\malgun.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\malgunbd.ttf")
BG = "#F8F5EC"
INK = "#322C23"
BODY = "#665F55"
GREEN = "#405733"
ACCENT = "#C8704D"


def font(size, bold=False):
    return ImageFont.truetype(str(FONT_BOLD if bold else FONT), size)


def wrap(draw, text, max_width, fnt):
    lines = []
    for paragraph in text.split("\n"):
        if not paragraph:
            lines.append("")
            continue
        current = ""
        for ch in paragraph:
            test = current + ch
            if draw.textbbox((0, 0), test, font=fnt)[2] > max_width and current:
                lines.append(current)
                current = ch
            else:
                current = test
        lines.append(current)
    return lines


def base(name, eyebrow, title, body):
    im = Image.new("RGB", (1920, 1080), BG)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 1920, 28), fill=GREEN)
    d.text((105, 95), eyebrow, font=font(25, True), fill=GREEN)
    d.text((105, 155), title, font=font(61, True), fill=INK)
    y = 390
    for line in wrap(d, body, 760, font(34)):
        d.text((110, y), line, font=font(34), fill=BODY)
        y += 58
    d.rounded_rectangle((105, 915, 710, 990), 28, fill=GREEN)
    d.text((145, 933), "QUEST  →  GROWTH  →  REWARD", font=font(24, True), fill="white")
    im.save(OUT / name)
    return im


def place_portrait(im, source):
    shot = Image.open(CACHE / source).convert("RGB")
    shot.thumbnail((585, 990), Image.Resampling.LANCZOS)
    x, y = 1225 + (585 - shot.width) // 2, 45 + (990 - shot.height) // 2
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((x - 10, y - 10, x + shot.width + 10, y + shot.height + 10), 24, fill="#DED7C6", outline=INK, width=5)
    im.paste(shot, (x, y))


def place_landscape(im, source):
    shot = Image.open(CACHE / source).convert("RGB")
    shot.thumbnail((980, 830), Image.Resampling.LANCZOS)
    x, y = 885 + (980 - shot.width) // 2, 125 + (830 - shot.height) // 2
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((x - 10, y - 10, x + shot.width + 10, y + shot.height + 10), 20, fill="#DED7C6", outline=INK, width=5)
    im.paste(shot, (x, y))


def make(name, eyebrow, title, body, source=None, portrait=True):
    im = base(name, eyebrow, title, body)
    if source:
        (place_portrait if portrait else place_landscape)(im, source)
    im.save(OUT / name)


make("01-title.png", "LIFEQUEST · PRODUCT DEMO", "일상을 퀘스트로,\n경험을 성장으로", "앱과 관리자 웹이 하나의 성장 경험으로 연결됩니다.")
make("02-home.png", "01 · HOME", "오늘의 모험을\n한눈에", "프로필 · 레벨 · EXP\n오늘의 퀘스트와 진행 상황\n성장한 루키 캐릭터", "emulator.png")
make("03-notifications.png", "02 · NOTIFICATIONS", "친구와 퀘스트 소식을\n바로 확인", "친구 신청\n새로운 일간 퀘스트\n완료 보상과 액세서리 획득", "notif4.png")
make("04-quests.png", "03 · QUESTS", "일간 · 주간 ·\nAI 퀘스트", "짧은 일상 행동부터 주간 목표까지.\nAI가 상황에 맞춘 퀘스트도 추천합니다.", "quests.png")
make("05-live-bg.png", "APP FLOW", "앱 안에서 이어지는\n주요 기능", "알림 → 친구 요청\n일간/주간/AI 퀘스트\n그룹 → 친구 → 랭킹", "notif4.png")
make("06-growth.png", "04 · SOCIAL & GROWTH", "함께 성장하고\n기록으로 남기기", "친구 목록과 랭킹\n퀘스트 완료 기록 · 누적 EXP\n도감 · 업적 · 칭호", "my4.png")
make("07-custom-bg.png", "05 · CUSTOMIZE", "루키는 고정,\n액세서리만 변경", "퀘스트 수행 → EXP/보상 획득\n액세서리 선택 → 미리보기 → 적용")
make("08-admin.png", "06 · ADMIN WEB", "서비스 전체 현황을\n운영자가 관리", "사용자 · 퀘스트 · 완료 · EXP 지표\n인기 퀘스트와 최근 활동", "admin-dashboard.png", False)
make("09-admin-form.png", "07 · ADMIN QUEST", "새 퀘스트 등록", "새로운 카페 방문하기\n일간 · 직접 완료 · 15 EXP", "admin-quest-form.png", False)
make("10-sync.png", "08 · SYNC", "등록 즉시 하나의\n백엔드로 연동", "관리자 웹 → REST API → 사용자 앱\n새 퀘스트가 앱 목록에 바로 반영됩니다.", "admin-quest-created.png", False)
make("11-outro.png", "LIFEQUEST", "퀘스트 → 성장 →\n보상 → 꾸미기", "일상의 작은 행동이 EXP와 보상이 되고,\n루키와 함께한 모험의 기록으로 쌓입니다.")
