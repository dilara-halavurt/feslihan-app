import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const PREDEFINED_TAGS = [
  "meze", "tatlı", "tuzlu", "atıştırmalık", "ana yemek", "çorba", "salata",
  "kahvaltı", "aperatif", "içecek", "hamur işi", "kek", "kurabiye", "pilav",
  "makarna", "et", "tavuk", "balık", "deniz ürünü", "vegan", "vejetaryen",
  "glutensiz", "hafif", "doyurucu", "pratik", "tek kişilik", "misafirler için",
  "çocuklar için", "diyet", "sağlıklı", "sokak lezzeti", "fast food",
  "geleneksel", "fırın", "ızgara", "kızartma",
];

interface AnalyzeRequest {
  caption?: string;
  transcription?: string;
  frames?: string[]; // base64 encoded images
  cover_image?: string; // base64 encoded cover/og:image (may have play icon)
}

interface MealPlanRequest {
  people_count: string;
  meals_per_day: string;
  eating_styles: string[];
  period: string;
  has_kids: boolean;
  kids_count: number;
  prep_style: string;
  budget: string;
  available_recipes?: { title: string; tags: string[]; cooking_time_minutes?: number; cuisine?: string; ingredients: string[] }[];
}

export async function analyzeRecipe(input: AnalyzeRequest) {
  const inputSections: string[] = [];

  if (input.caption) {
    inputSections.push(`Video aciklamasi (caption):\n${input.caption}`);
  }
  if (input.transcription) {
    inputSections.push(`Ses transkripsiyonu:\n${input.transcription}`);
  }
  if (!input.frames?.length && inputSections.length === 0) {
    inputSections.push("Gorsel veya metin verisi yok.");
  }

  const prompt = `Sen bir yemek tarifi asistanisin. Sana bir yemek videosundan elde edilen bilgiler verilecek: video aciklamasi (caption), video kareleri ve/veya ses transkripsiyonu. Bunlarin hepsini birlikte analiz ederek Turkce olarak yapilandirilmis bir tarif olustur.

EN ONEMLI KAYNAK: Video aciklamasi (caption) genellikle tarif detaylarini, malzemeleri ve miktarlari icerir. Bunu mutlaka dikkate al.

Videodaki yazi katmanlarini (text overlay) ve gorselleri de dikkatlice incele.

${inputSections.join("\n\n")}

KRITIK KURAL - ONCE BUNU DEGERLENDIR:
Icerigin gercekten bir yemek tarifi olup olmadigini belirle. Bir icerik SADECE su durumlarda tariftir: acikca malzemeler ve yapilis adimlari iceriyorsa VEYA birinin yemek pisirme surecini gosteriyorsa. Asagidakiler tarif DEGILDIR:
- Restoran/kafe tanitimi veya yemek yeme videolari (mukbang)
- Yemekle ilgisi olmayan icerikler (muzik, dans, komedi, moda, spor, seyahat, oyun, teknoloji)
- Sadece yemek gorseli paylasimi (tarif icermeyen)
- Alisveris, market turu videolari
- Genel yasam tarzi/vlog icerikleri

Eger icerik bir yemek tarifi DEGILSE, asagidaki JSON'u dondur ve BASKA HICBIR SEY YAZMA:
{"is_recipe": false}

ASLA tarif uydurmayacaksin. Eger caption veya gorsellerde net bir tarif (malzeme + yapilis) yoksa, is_recipe: false dondur.

Eger icerik bir yemek tarifi ISE, asagidaki JSON formatinda yanit ver (baska hicbir sey yazma):
{
    "is_recipe": true,
    "title": "Tarifin Turkce adi",
    "ingredients": [
        {
            "name": "Malzeme adi (Turkce)",
            "amount": "Miktar ve birimi"
        }
    ],
    "base_ingredients": ["tereyagi", "yumurta", "un", "seker", "sut"],
    "instructions": "Adim adim yapilis tarifi (Turkce, her adim yeni satirda)",
    "cooking_time_minutes": 25,
    "servings": 4,
    "calories_total_kcal": 1200.0,
    "calories_per_serving_kcal": 300.0,
    "protein_grams": 25.0,
    "carbs_grams": 150.0,
    "fat_grams": 40.0,
    "fiber_grams": 8.0,
    "difficulty": "medium",
    "cuisine": "turkish",
    "tags": ["tatli", "misafirler icin"],
    "best_thumbnail_index": 0,
    "platform_user": "videodaki kullanici adi (caption'dan cikart, @ isareti olmadan)",
    "likes_count": 27000,
    "comments_count": 540
}

Onemli kurallar:
- Tum icerik Turkce olmali
- Miktarlar net olmali (ornegin: "2 su bardagi", "1 tatli kasigi")
- Icerik baska bir dilde ise Turkce'ye cevir
- Caption, ses ve gorsellerdeki bilgileri birlestirerek en eksiksiz tarifi olustur
- base_ingredients: Tekil, kisa, standart malzeme isimleri (tekrarsiz). Ornekler: "tereyagi", "yumurta", "un", "sut", "seker", "tuz", "zeytinyagi", "sogan", "sarimsak", "domates", "biber", "maydanoz". Aciklama veya miktar EKLEME, sadece malzeme adi yaz. Turkce kucuk harf.
- ONEMLI: Eger yapilis adimlarinda gecen ama malzeme listesinde olmayan malzemeler varsa (ornegin "tuz", "karabiber", "su", "zeytinyagi" gibi), bunlari da "ingredients" listesine miktar belirtmeden ekle (amount: "").  base_ingredients'a da ekle.
- Kalorileri ve makrolari malzemelere ve miktarlara gore tahmin et (kesin olmasi gerekmez)
- cuisine: Tarifin mutfak turunu belirle. Degerler: "italian", "chinese", "mexican", "indian", "thai", "french", "japanese", "mediterranean", "turkish", "other"
- calories_total_kcal: Tum tarifin toplam kalorisi
- calories_per_serving_kcal: Kisi basina kalori
- protein_grams, carbs_grams, fat_grams, fiber_grams: Tum tarifin toplam makrolari (gram)
- cooking_time_minutes: Tahmini toplam pisirme suresi DAKIKA cinsinden (sayi olarak). Ornegin: 15 dk ise 15, 1.5 saat ise 90, 2 saat ise 120. ASLA null olmamali.
- difficulty: Tarifin zorluk seviyesi - "low" (kolay/az islem), "medium" (orta), "high" (zor/cok islem)
- servings: Tarifin kac kisilik oldugu (sayi olarak)
- tags: Tarife uygun etiketler (Turkce karakterlerle, kucuk harf, tekrarsiz). SADECE su etiketlerden sec: ${PREDEFINED_TAGS.map(t => `"${t}"`).join(", ")}. Baska etiket KULLANMA. En fazla 5 etiket sec.
- best_thumbnail_index: Eger birden fazla gorsel varsa, kapak gorseline (ilk gorsel) en cok benzeyen ama oynatma (play) ikonu OLMAYAN gorselin sira numarasini yaz (0'dan baslar, kapak gorseli 0). Eger sadece kapak gorseli varsa veya hicbir gorsel yoksa 0 yaz.
- platform_user: Videoyu paylasan kullanicinin adi. Caption'dan cikart. "@" isareti varsa kaldir. Ornegin "27K likes, 540 comments - chefayse on ..." -> "chefayse". Veya "@mutfaktayiz" -> "mutfaktayiz". Bulamazsan null yaz.
- likes_count: Videonun begeni sayisi. Caption'dan cikart. "27K likes" -> 27000, "1.5M likes" -> 1500000. Bulamazsan 0 yaz.
- comments_count: Videonun yorum sayisi. Caption'dan cikart. "540 comments" -> 540. Bulamazsan 0 yaz.`;

  const content: Anthropic.MessageCreateParams["messages"][0]["content"] = [];

  // Send cover image first (index 0), then frames
  if (input.cover_image) {
    content.push({
      type: "image",
      source: { type: "base64", media_type: "image/jpeg", data: input.cover_image },
    });
  }

  if (input.frames?.length) {
    for (const frame of input.frames) {
      content.push({
        type: "image",
        source: { type: "base64", media_type: "image/jpeg", data: frame },
      });
    }
  }

  content.push({ type: "text", text: prompt });

  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 8192,
    messages: [{ role: "user", content }],
  });

  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("No text response from Claude");
  }

  const jsonString = textBlock.text
    .replace(/```json/g, "")
    .replace(/```/g, "")
    .trim();

  return JSON.parse(jsonString);
}

export async function generateMealPlan(input: MealPlanRequest) {
  const kidsInfo = input.has_kids
    ? `${input.kids_count} çocuk var, çocuk dostu yemekler de ekle.`
    : "Çocuk yok, sadece yetişkinler.";

  const recipeList = (input.available_recipes ?? [])
    .map((r, i) => `${i + 1}. ${r.title} (${r.cooking_time_minutes ?? "?"} dk) [${r.tags.join(", ")}] - Malzemeler: ${r.ingredients.join(", ")}`)
    .join("\n");

  const prompt = `Sen bir meal prep (yemek hazırlık) uzmanısın. Kullanıcı için detaylı bir yemek planı oluştur.

Kullanıcı bilgileri:
- Kişi sayısı: ${input.people_count}
- Günlük öğün: ${input.meals_per_day}
- Beslenme tarzı: ${input.eating_styles.join(", ")}
- Plan süresi: ${input.period}
- Çocuk durumu: ${kidsInfo}
- Hazırlık tarzı: ${input.prep_style}
- Bütçe: ${input.budget}

KULLANICININ MEVCUT TARİFLERİ:
${recipeList || "Tarif yok."}

Kurallar:
- SADECE yukarıdaki tarif listesinden seç. Yeni tarif UYDURMA.
- Tarif isimleri listede yazdığı gibi AYNI olmalı, değiştirme.
- Eğer yeterli tarif yoksa, mevcut tarifleri farklı günlerde tekrar kullan.
- Tüm içerik Türkçe olmalı
- Yemekler mümkün olduğunca çeşitli olmalı
- Beslenme tarzına uygun tarifleri seç
- Malzemeler mümkün olduğunca ortak olsun (meal prep mantığı)
- Bütçeye uygun malzemeler kullan
- Eğer çocuk varsa çocuk dostu tarifleri tercih et
- Plan süresine göre gün sayısını ayarla (${input.period})
- Hazırlık tarzına dikkat et: "${input.prep_style}" seçildi. "Hazırla & Dondur" ise dondurulabilir tarifleri seç. "Her Gün Taze" ise hızlı tarifleri seç. "Karışık" ise karıştır.

SADECE aşağıdaki JSON formatında yanıt ver (başka hiçbir şey yazma):
{
    "days": [
        {
            "day_name": "Pazartesi",
            "meals": [
                {
                    "meal_type": "Kahvaltı",
                    "name": "Yemek adı",
                    "description": "Kısa açıklama",
                    "calories": 350,
                    "ingredients": ["malzeme1", "malzeme2"]
                }
            ]
        }
    ],
    "shopping_list": ["1 kg tavuk göğsü", "500g pirinç", "..."],
    "avg_calories_per_day": 2000
}

Önemli:
- Her gün için öğün sayısı ${input.meals_per_day} olmalı
- shopping_list tüm plan için toplu alışveriş listesi olmalı (miktar dahil)
- calories her öğün için tahmini kalori
- avg_calories_per_day günlük ortalama kalori`;

  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 16384,
    messages: [{ role: "user", content: prompt }],
  });

  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("No text response from Claude");
  }

  const jsonString = textBlock.text
    .replace(/```json/g, "")
    .replace(/```/g, "")
    .trim();

  return JSON.parse(jsonString);
}
