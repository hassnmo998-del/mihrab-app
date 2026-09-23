import os
import sys
import subprocess
import platform

# المجلدات والملفات اللي رح نتجاهلها مشان الشجرة تضل نظيفة (خاصة بمشاريع فلاتر)
IGNORE_LIST = {'.git', '.dart_tool', 'build', '.idea', '__pycache__', 'windows', 'linux', 'macos', 'web'}

# ─────────────────────────────────────────────
#  نسخ للحافظة (Windows / macOS / Linux)
# ─────────────────────────────────────────────
def copy_to_clipboard(text: str) -> bool:
    try:
        system = platform.system()
        if system == "Windows":
            subprocess.run("clip", input=text.encode("utf-16"), check=True)
        elif system == "Darwin":
            subprocess.run("pbcopy", input=text.encode("utf-8"), check=True)
        else:
            # Linux – نجرب xclip ثم xsel
            try:
                subprocess.run(["xclip", "-selection", "clipboard"],
                               input=text.encode("utf-8"), check=True)
            except FileNotFoundError:
                subprocess.run(["xsel", "--clipboard", "--input"],
                               input=text.encode("utf-8"), check=True)
        return True
    except Exception:
        return False

# ─────────────────────────────────────────────
#  رسم الشجرة (يرجع النص بدل ما يطبعه مباشرة)
# ─────────────────────────────────────────────
def build_tree(directory: str, prefix: str = "") -> str:
    lines = []
    try:
        entries = sorted(os.scandir(directory), key=lambda e: (e.is_file(), e.name.lower()))
    except PermissionError:
        lines.append(prefix + "  [🚫 ممنوع الوصول]")
        return "\n".join(lines)

    valid_entries = [e for e in entries if e.name not in IGNORE_LIST]
    count = len(valid_entries)

    for i, entry in enumerate(valid_entries):
        is_last = i == (count - 1)
        connector = "└── " if is_last else "├── "
        lines.append(prefix + connector + entry.name)

        if entry.is_dir():
            extension = "    " if is_last else "│   "
            lines.append(build_tree(entry.path, prefix + extension))

    return "\n".join(filter(None, lines))

# ─────────────────────────────────────────────
#  البحث الذكي عن المجلد
# ─────────────────────────────────────────────
SEARCH_ROOT = os.getcwd()

def smart_find(name: str, search_root: str = None) -> list[str]:
    """
    يبحث عن مجلد باسمه فقط داخل search_root.
    يرجع قائمة بكل المسارات اللي لقاها.
    """
    if search_root is None:
        search_root = SEARCH_ROOT

    matches = []
    try:
        for root, dirs, _ in os.walk(search_root):
            # تجاهل المجلدات المزعجة أثناء البحث لتسريعه
            dirs[:] = [d for d in dirs if d not in IGNORE_LIST and not d.startswith('.')]
            for d in dirs:
                if d.lower() == name.lower():
                    matches.append(os.path.join(root, d))
    except PermissionError:
        pass
    return matches

# ─────────────────────────────────────────────
#  تحليل المدخل: مسار كامل؟ اسم فقط؟
# ─────────────────────────────────────────────
def resolve_path(user_input: str) -> str | None:
    """
    يحاول يحدد المسار الصحيح ويرجعه، أو None لو فشل.
    """
    user_input = user_input.strip()

    # ─ حالة 1: مسار موجود مباشرة ─
    if os.path.exists(user_input) and os.path.isdir(user_input):
        return os.path.abspath(user_input)

    # ─ حالة 2: اسم مجلد بسيط (بدون فاصل مسار) ─
    is_simple_name = (os.sep not in user_input) and ("/" not in user_input)
    if not is_simple_name:
        return None  # مسار خاطئ أو غير موجود

    print(f"\n🔍 ما لقيت مسار مباشر، أبحث عن مجلد اسمه '{user_input}' ...")
    matches = smart_find(user_input)

    if not matches:
        print(f"❌ ما لقيت أي مجلد اسمه '{user_input}' في المجلدات الرئيسية.")
        return None

    if len(matches) == 1:
        print(f"✅ لقيته: {matches[0]}")
        return matches[0]

    # ─ حالة 3: وجد بأكثر من مكان ─
    print(f"\n⚠️  لقيت '{user_input}' في {len(matches)} مكان، أيهم تقصد؟\n")
    for idx, path in enumerate(matches, 1):
        print(f"  {idx}) {path}")
    print()

    while True:
        choice = input("اكتب رقم الخيار: ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(matches):
            return matches[int(choice) - 1]
        print("⚠️  رقم غلط، حاول مرة.")

# ─────────────────────────────────────────────
#  البرنامج الرئيسي
# ─────────────────────────────────────────────
def main():
    print("\n🌳 أداة رسم شجرة المجلدات 🌳\n")
    user_input = input("دخل مسار أو اسم المجلد (أو اضغط Enter للمجلد الحالي): ").strip()

    if not user_input:
        folder_path = os.path.abspath(SEARCH_ROOT)
    else:
        folder_path = resolve_path(user_input)

    if not folder_path:
        print("\n❌ المسار مو موجود أو مو مجلد صحيح! تأكد منه يا شريك.\n")
        sys.exit(1)

    # ─ رسم الشجرة ─
    header = f"📂 {folder_path}"
    tree_body = build_tree(folder_path)
    full_output = f"{header}\n{tree_body}"

    print(f"\n{full_output}\n")
    print("✅ انتهى الرسم!")

    # ─ نسخ للحافظة ─
    if copy_to_clipboard(full_output):
        print("📋 تم نسخ الشجرة للحافظة تلقائياً!\n")
    else:
        print("⚠️  ما قدرت أنسخ للحافظة (تأكد أن xclip أو xsel مثبت على Linux).\n")

if __name__ == "__main__":
    main()