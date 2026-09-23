; مثبّت محراب لويندوز.
;
; يُبنى من GitHub Actions مع تمرير الإصدار:
;   iscc /DAppVersion=1.2.0 /DTagName=v1.2.0 installer\mihrab.iss
;
; ومحلياً للتجربة (يأخذ 0.0.0 إن لم يُمرَّر شيء):
;   iscc installer\mihrab.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef TagName
  #define TagName "v" + AppVersion
#endif

#define AppName      "محراب"
#define AppExeName   "flutter_app.exe"
#define BuildDir     "..\flutter_app\build\windows\x64\runner\Release"

[Setup]
; ── لا تغيّره ────────────────────────────────────────────────────────────
; هوية التطبيق عند ويندوز، ثابتة مدى العمر.
;
; كانت وصفة المثبّت تُولَّد نصاً داخل الـ workflow في كل تشغيل بلا AppId، فيُولّد
; Inno واحداً جديداً كل مرة. وتغيّر AppId يجعل ويندوز يرى التحديث برنامجاً
; مختلفاً: يُثبَّت إلى جانب القديم بدل أن يحلّ محلّه، ويظهر التطبيق مرتين في
; قائمة البرامج. ووجود الوصفة كملف ثابت في المستودع هو ما يضمن ثباته.
AppId={{55F5CBCD-A28A-45AE-84FD-F2C59E314981}

; ── لا تغيّرهما ──────────────────────────────────────────────────────────
; تثبيت تحت حساب المستخدم، لا في Program Files.
;
; التطبيق يحدّث نفسه: ينزّل المثبّت ويشغّله صامتاً. والتثبيت في Program Files
; يحتاج صلاحيات مدير، فيقطع ويندوز التحديث «الصامت» بنافذة UAC لا يعرف
; المستخدم من أين جاءت — أو يفشل التحديث بلا أثر. وكذلك {commondesktop}
; لاختصار سطح المكتب: يحتاج رفع صلاحيات، و{autodesktop} لا يحتاج.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Mihrab
; ─────────────────────────────────────────────────────────────────────────

AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
VersionInfoVersion={#AppVersion}
AppPublisher=Mihrab
DefaultGroupName={#AppName}

OutputDir=..\installer_output
OutputBaseFilename=mihrab-windows-{#TagName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

SetupIconFile=..\flutter_app\assets\images\logo.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

[Languages]
Name: "arabic";  MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"

[Files]
; مجلد البناء كاملاً: الـ exe وحده لا يعمل، يحتاج ملفات DLL ومجلد data بجانبه.
;
; الاستثناءات مخلّفات لا ينظّفها فلاتر بين أنواع البناء:
;   kernel_blob.bin — كود Dart بصيغة kernel من بناء debug، بمئات الميغابايت.
;       نسخة الإصدار تعمل على data\app.so وحده ولا تقرأه، وهو أيسر بكثير في
;       الهندسة العكسية منه.
;   *.exp و *.lib — مخلّفات الرابط، لا تُستعمل وقت التشغيل.
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
    Excludes: "kernel_blob.bin,*.exp,*.lib"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; skipifsilent يمنع تشغيل التطبيق أثناء التحديث التلقائي، حيث يتولّى التطبيق
; إعادة تشغيل نفسه — وبدونها يعمل مرتين.
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent
