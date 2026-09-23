# وصول Supabase — مشروع المسجد

> **التوكن ليس مكتوباً في هذا الملف عمداً.** كل موضع مكتوب فيه `<PAT>` استبدله بالتوكن.
>
> **من أين تجلب التوكن؟** إما من ملف `~/.claude.json` عندك تحت
> `mcpServers` › `supabase-masjed` › `env` › `SUPABASE_ACCESS_TOKEN`،
> أو ولّد واحداً جديداً من: https://supabase.com/dashboard/account/tokens
>
> ⚠️ التوكن يعادل كلمة سر حساب Supabase. لا ترفع هذا الملف على GitHub بعد تعبئته.

---

## المعرّفات

| | |
|---|---|
| Project ref | `mltxsmonudbtnrloqawf` |
| Project URL | `https://mltxsmonudbtnrloqawf.supabase.co` |
| المنظمة | `ohxrczcguowjcvupvukm` — حساب `hassnmo998@gmail.com` |
| Publishable key (مفتاح التطبيق العام، غير سرّي) | `sb_publishable_yr45qpkrG5Fp20pAbS7NJg_DCIYQHuf` |
| Personal Access Token (إداري، سرّي) | `<PAT>` |

---

## الطريقة ١ — خادم MCP المستضاف ✅ الأفضل

يعمل مع أي عميل يدعم MCP عبر HTTP، بلا تثبيت أي شيء، وبلا تسجيل دخول تفاعلي.

```json
{
  "mcpServers": {
    "supabase-masjed": {
      "type": "http",
      "url": "https://mcp.supabase.com/mcp?project_ref=mltxsmonudbtnrloqawf",
      "headers": {
        "Authorization": "Bearer <PAT>"
      }
    }
  }
}
```

معاملات إضافية تُضاف على الرابط:

| المعامل | الأثر |
|---|---|
| `&read_only=true` | تنفيذ كل الاستعلامات بمستخدم قراءة فقط |
| `&features=database,docs` | حصر الأدوات المتاحة بمجموعات محددة |

`project_ref` في الرابط يحصر الوكيل بهذا المشروع وحده، ويعطّل أدوات إدارة الحساب.

## الطريقة ٢ — خادم MCP محلي (stdio)

```bash
npm install -g @supabase/mcp-server-supabase
```

```json
{
  "mcpServers": {
    "supabase-masjed": {
      "command": "mcp-server-supabase",
      "args": ["--project-ref=mltxsmonudbtnrloqawf"],
      "env": { "SUPABASE_ACCESS_TOKEN": "<PAT>" }
    }
  }
}
```

> ملاحظة: استخدام `npx -y @supabase/mcp-server-supabase@latest` بدل الأمر المثبّت
> يجعل أول إقلاع يتجاوز مهلة الاتصال (30 ثانية) لأنه ينزّل الحزمة. ثبّتها عالمياً أولاً.

## الطريقة ٣ — بلا MCP: نداء HTTP مباشر

إن كان الوكيل الآخر لا يدعم MCP لكنه ينفّذ أوامر/كوداً، فهذه أبسط طريقة وأكثرها مرونة.

**تشغيل أي SQL** — قراءة وكتابة و DDL — عبر Management API:

```javascript
const TOKEN = '<PAT>';
const REF = 'mltxsmonudbtnrloqawf';

async function sql(query) {
  const r = await fetch(
    `https://api.supabase.com/v1/projects/${REF}/database/query`,
    {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + TOKEN,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query }),
    }
  );
  return r.json();
}

sql("select tablename from pg_tables where schemaname='public'").then(console.log);
```

**قراءة وكتابة البيانات كما يفعل التطبيق نفسه** (REST + المفتاح العام، يخضع لسياسات RLS):

```bash
curl "https://mltxsmonudbtnrloqawf.supabase.co/rest/v1/mosques?select=*" \
  -H "apikey: sb_publishable_yr45qpkrG5Fp20pAbS7NJg_DCIYQHuf" \
  -H "Authorization: Bearer sb_publishable_yr45qpkrG5Fp20pAbS7NJg_DCIYQHuf"
```

---

## ما لا يستطيعه التوكن

هذه محصورة بلوحة التحكم، فلا تضيّع وقتك في محاولتها برمجياً:

- تغيير إعدادات المصادقة (مثل تعطيل التسجيل العام)
- دعوة أعضاء للمنظمة أو نقل المشاريع — الـ API يوفّر `GET members` فقط
- جلب المفاتيح السرية في بعض البيئات

---

## بنية قاعدة البيانات — 19 جدولاً

```
attendance, community_events, competitions, event_questions, halaqat,
intensive_courses, memorization_records, messages, mosques, points_logs,
recitation_tracks, registration_tokens, reward_redemptions, rewards,
sheikhs, students, subject_recitation_records, super_admins, trips
```

### نموذج الصلاحيات — مهم جداً

- **17 جدولاً** عليها سياسة واحدة: `Allow all operations for anon`.
  أي أن المفتاح العام يقرأ ويكتب فيها بحرية تامة. لا يوجد فصل صلاحيات على مستوى قاعدة البيانات.
- **`super_admins`** الاستثناء الوحيد: RLS صارم — القراءة للمستخدم المصادَق وصفه هو فقط،
  ولا توجد سياسة كتابة إطلاقاً. منح الصلاحية يتم عبر SQL حصراً.
- **Realtime** مفعّل على `registration_tokens` و `community_events`.

### المصادقة

مصادقة المشرف العام تمر عبر **Supabase Auth** (`admin@masjed.app`)، وليست كلمة سر مخزّنة في جدول.
التحقق من الصلاحية يتم بقراءة صف من `super_admins` بعد تسجيل الدخول.

### تحذير معلّق

التسجيل العام مفعّل (`disable_signup: false`) — حامل المفتاح العام يستطيع إنشاء حسابات.
لا يمنحه ذلك أي صلاحية (لا صف له في `super_admins`)، لكن يُستحسن تعطيله من:
**Authentication › Sign In / Providers › Allow new users to sign up**

---

## تخزين الوسائط

التسجيلات الصوتية والمرئية ليست في Supabase Storage، بل في **تيليجرام**.
تُحفظ في قاعدة البيانات كمرجع دائم بصيغة `tg:audio:<file_id>` أو `tg:video:<file_id>`،
ويُحوَّل إلى رابط طازج عند كل تشغيل، لأن روابط تيليجرام تنتهي صلاحيتها بعد ساعة.
التفاصيل في `lib/services/telegram_media_resolver.dart`.
