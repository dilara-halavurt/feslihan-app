import "dotenv/config";
import express from "express";
import https from "https";
import { db } from "./db.js";
import { recipes, ingredients, tags, platformCreators, userRecipes, userFolders, users, mealPlans, userPantry, userShoppingList, recipeReviews } from "./schema.js";
import { uploadImage, s3KeyFromUrl, getImage } from "./s3.js";
import { analyzeRecipe, analyzeNutrition, generateMealPlan, classifyIngredients, classifyFreezerFriendly } from "./ai.js";
import { eq, desc, inArray, and, sql, isNull } from "drizzle-orm";

const app = express();
app.use(express.json({ limit: "50mb" }));

const PREDEFINED_TAGS = [
  "meze",
  "tatlı",
  "tuzlu",
  "atıştırmalık",
  "ana yemek",
  "çorba",
  "salata",
  "kahvaltı",
  "aperatif",
  "içecek",
  "hamur işi",
  "kek",
  "kurabiye",
  "pilav",
  "makarna",
  "et",
  "tavuk",
  "balık",
  "deniz ürünü",
  "vegan",
  "vejetaryen",
  "glutensiz",
  "hafif",
  "doyurucu",
  "pratik",
  "tek kişilik",
  "misafirler için",
  "çocuklar için",
  "diyet",
  "sağlıklı",
  "sokak lezzeti",
  "fast food",
  "geleneksel",
  "fırın",
  "ızgara",
  "kızartma",
];

// Request logging
app.use((req, _res, next) => {
  const body = req.body;
  const bodySize = JSON.stringify(body || {}).length;
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.path} (${(bodySize / 1024).toFixed(1)}KB)`);
  if (body && req.method === "POST") {
    console.log(`  title: ${body.title || "-"}`);
    console.log(`  url: ${body.url || "-"}`);
    console.log(`  thumbnail_base64: ${body.thumbnail_base64 ? `${(body.thumbnail_base64.length / 1024).toFixed(0)}KB` : "MISSING"}`);
    console.log(`  cuisine: ${body.cuisine || "-"}, difficulty: ${body.difficulty || "-"}, cooking_time: ${body.cooking_time || "-"}`);
    console.log(`  calories: ${body.calories_total_kcal || "-"}, servings: ${body.servings || "-"}`);
    console.log(`  ingredients: ${body.ingredients_without_measures?.length || 0} base items`);
  }
  next();
});

function toSnake(obj: any): any {
  if (Array.isArray(obj)) return obj.map(toSnake);
  if (obj !== null && typeof obj === "object" && !(obj instanceof Date)) {
    return Object.fromEntries(
      Object.entries(obj).map(([k, v]) => [
        k.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`),
        v instanceof Date ? v.toISOString() : toSnake(v),
      ])
    );
  }
  return obj;
}

function rewriteThumbnail(obj: any): any {
  if (Array.isArray(obj)) return obj.map(rewriteThumbnail);
  if (obj && typeof obj === "object" && obj.thumbnail_url) {
    const key = s3KeyFromUrl(obj.thumbnail_url);
    if (key) {
      return { ...obj, thumbnail_url: `/images/${key}` };
    }
  }
  return obj;
}

function parseCookingTime(str: string | null | undefined): number | null {
  if (!str) return null;
  const lower = str.toLowerCase().trim();
  let total = 0;
  // "1 sa 15 dk" or "1.5 sa 30 dk"
  const hourMatch = lower.match(/([\d.,]+)\s*sa/);
  if (hourMatch) total += Math.round(parseFloat(hourMatch[1].replace(",", ".")) * 60);
  const minMatch = lower.match(/([\d.,]+)\s*dk/);
  if (minMatch) total += Math.round(parseFloat(minMatch[1].replace(",", ".")));
  if (total > 0) return total;
  // Plain number -> assume minutes
  const num = parseFloat(lower);
  if (!isNaN(num)) return Math.round(num);
  return null;
}

function parseCount(str: string): number | null {
  if (!str) return null;
  const lower = str.toLowerCase().replace(/,/g, "");
  const num = parseFloat(lower);
  if (isNaN(num)) return null;
  if (lower.endsWith("k")) return Math.round(num * 1000);
  if (lower.endsWith("m")) return Math.round(num * 1000000);
  return Math.round(num);
}

function parseCaptionMeta(caption: string | null | undefined) {
  if (!caption) return { likesCount: null, commentsCount: null, platformUser: null };

  let likesCount: number | null = null;
  let commentsCount: number | null = null;
  let platformUser: string | null = null;

  // Instagram: "27K likes, 540 comments - username on ..."
  const likesMatch = caption.match(/^([\d.,]+[KkMm]?)\s+likes?/i);
  if (likesMatch) likesCount = parseCount(likesMatch[1]);

  const commentsMatch = caption.match(/([\d.,]+[KkMm]?)\s+comments?/i);
  if (commentsMatch) commentsCount = parseCount(commentsMatch[1]);

  const userMatch = caption.match(/comments?\s*-\s*(\S+)\s+on\s/i)
    || caption.match(/^(\S+)\s+on\s+\w+\s+\d/i);
  if (userMatch) platformUser = userMatch[1];

  // TikTok: caption often contains "@username" or "username on TikTok"
  if (!platformUser) {
    const tiktokMatch = caption.match(/@(\w[\w.]+)/);
    if (tiktokMatch) platformUser = tiktokMatch[1];
  }

  return { likesCount, commentsCount, platformUser };
}

function extractUserFromURL(url: string): string | null {
  // TikTok: tiktok.com/@username/video/...
  const tiktokMatch = url.match(/tiktok\.com\/@([^/]+)/i);
  if (tiktokMatch) return tiktokMatch[1];

  // X/Twitter: x.com/username/status/...
  const xMatch = url.match(/(?:x\.com|twitter\.com)\/([^/]+)\/status/i);
  if (xMatch) return xMatch[1];

  return null;
}

// Word-level Turkish character fixes (ASCII → proper Turkish)
const turkishWordMap: Record<string, string> = {
  sarimsak: "sarımsak",
  sogan: "soğan",
  sogani: "soğanı",
  kiyma: "kıyma",
  feslegen: "fesleğen",
  cilek: "çilek",
  salca: "salça",
  salcasi: "salçası",
  nisasta: "nişasta",
  kirmizi: "kırmızı",
  yesil: "yeşil",
  kasar: "kaşar",
  yogurt: "yoğurt",
  sut: "süt",
  tereyagi: "tereyağı",
  zeytinyagi: "zeytinyağı",
  seker: "şeker",
  sekeri: "şekeri",
  pirinc: "pirinç",
  havuc: "havuç",
  patlican: "patlıcan",
  fistik: "fıstık",
  fistigi: "fıstığı",
  ispanak: "ıspanak",
  baligi: "balığı",
  yapragi: "yaprağı",
  tatli: "tatlı",
  misir: "mısır",
  pirasa: "pırasa",
  salatalik: "salatalık",
  seftali: "şeftali",
  kayisi: "kayısı",
  visne: "vişne",
  uzum: "üzüm",
  cicek: "çiçek",
  corek: "çörek",
  corekotu: "çörekotu",
  aci: "acı",
  bugday: "buğday",
  cesnisi: "çeşnisi",
  pastirma: "pastırma",
  corba: "çorba",
  borek: "börek",
  guvec: "güveç",
  kofte: "köfte",
  tursu: "turşu",
  recel: "reçel",
  lavash: "lavaş",
  cikolata: "çikolata",
  biskuvi: "bisküvi",
  eriste: "erişte",
  findik: "fındık",
  kori: "köri",
  kornison: "kornişon",
  yagi: "yağı",
  yag: "yağ",
  eksisi: "ekşisi",
  sivi: "sıvı",
  siviyag: "sıvıyağ",
  tatlandirici: "tatlandırıcı",
  zerdecal: "zerdeçal",
  arpacik: "arpacık",
  ezmesi: "ezmesi",
  cipsi: "cipsi",
  mercimek: "mercimek",
  peyniri: "peyniri",
  pudra: "pudra",
  kabartma: "kabartma",
  fasulye: "fasulye",
  dolma: "dolma",
  sucuk: "sucuk",
  susam: "susam",
  kuskus: "kuskus",
  incir: "incir",
};

function turkishCapitalize(str: string): string {
  if (!str) return str;
  const first = str[0];
  if (first === "i") return "İ" + str.slice(1);
  if (first === "ı") return "I" + str.slice(1);
  return first.toLocaleUpperCase("tr-TR") + str.slice(1);
}

function fixTurkish(name: string): string {
  const lower = name.toLocaleLowerCase("tr-TR").trim();
  // Fix each word individually
  const fixed = lower.split(/\s+/).map((w) => turkishWordMap[w] ?? w).join(" ");
  return turkishCapitalize(fixed);
}

async function resolveIngredientMap(names: string[]): Promise<Map<string, string>> {
  const nameToId = new Map<string, string>();
  if (!names || names.length === 0) return nameToId;

  const normalized = names.map((n) => fixTurkish(n)).filter(Boolean);
  if (normalized.length === 0) return nameToId;

  const unique = [...new Set(normalized)];
  const existing = await db
    .select({ id: ingredients.id, name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.name, unique));

  for (const r of existing) nameToId.set(r.name, r.id);
  const newNames = unique.filter((n) => !nameToId.has(n));

  if (newNames.length > 0) {
    const inserted = await db
      .insert(ingredients)
      .values(newNames.map((name) => ({ name })))
      .onConflictDoNothing()
      .returning();
    for (const row of inserted) {
      nameToId.set(row.name, row.id);
    }
    console.log(`Registered ${newNames.length} new ingredient(s): ${newNames.join(", ")}`);
  }

  return nameToId;
}

async function resolveIngredientIds(names: string[]): Promise<string[]> {
  if (!names || names.length === 0) return [];
  const normalized = names.map((n) => fixTurkish(n)).filter(Boolean);
  const nameToId = await resolveIngredientMap(names);
  return normalized.map((n) => nameToId.get(n)).filter(Boolean) as string[];
}

type ShoppingListItem = { name: string; amount: string; ingredient_id: string };

async function buildShoppingListFromRecipes(recipeIds: string[]): Promise<ShoppingListItem[]> {
  if (!recipeIds || recipeIds.length === 0) return [];

  const recipeRows = await db
    .select({
      ingredientsWithMeasures: recipes.ingredientsWithMeasures,
    })
    .from(recipes)
    .where(inArray(recipes.id, recipeIds));

  // Aggregate ingredients, dedup by name
  const map = new Map<string, { displayName: string; amounts: string[] }>();
  const order: string[] = [];

  for (const row of recipeRows) {
    const ings = row.ingredientsWithMeasures as { name: string; amount: string }[] ?? [];
    for (const ing of ings) {
      const name = (ing.name ?? "").trim();
      const amount = (ing.amount ?? "").trim();
      if (!name) continue;
      const key = name.toLocaleLowerCase("tr-TR");
      if (!map.has(key)) {
        order.push(key);
        map.set(key, { displayName: name, amounts: [] });
      }
      if (amount) {
        map.get(key)!.amounts.push(amount);
      }
    }
  }

  // Resolve ingredient IDs
  const displayNames = order.map((k) => map.get(k)!.displayName);
  const idMap = await resolveIngredientMap(displayNames);

  return order.map((key) => {
    const entry = map.get(key)!;
    const fixedName = fixTurkish(entry.displayName);
    const amounts = entry.amounts;
    const amount =
      amounts.length === 0 ? "" :
      amounts.length === 1 ? amounts[0] :
      amounts.join(" + ");
    return {
      name: entry.displayName,
      amount,
      ingredient_id: idMap.get(fixedName) ?? "",
    };
  }).filter((item) => item.ingredient_id);
}

async function resolveIngredientNames(ids: string[]): Promise<string[]> {
  if (!ids || ids.length === 0) return [];
  // Filter out any non-UUID values (legacy string names)
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const validIds = ids.filter((id) => uuidPattern.test(id));
  if (validIds.length === 0) return ids; // already names, return as-is

  const rows = await db
    .select({ id: ingredients.id, name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.id, validIds));

  const idToName = new Map(rows.map((r) => [r.id, r.name]));
  return ids.map((id) => idToName.get(id) ?? id);
}

async function resolveTagIds(names: string[]): Promise<string[]> {
  if (!names || names.length === 0) return [];
  const unique = [...new Set(names)];

  const existing = await db
    .select({ id: tags.id, name: tags.name })
    .from(tags)
    .where(inArray(tags.name, unique));

  const nameToId = new Map(existing.map((r) => [r.name, r.id]));
  return names.map((n) => nameToId.get(n)).filter(Boolean) as string[];
}

async function resolveTagNames(ids: string[]): Promise<string[]> {
  if (!ids || ids.length === 0) return [];
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const validIds = ids.filter((id) => uuidPattern.test(id));
  if (validIds.length === 0) return ids; // already names, return as-is

  const rows = await db
    .select({ id: tags.id, name: tags.name })
    .from(tags)
    .where(inArray(tags.id, validIds));

  const idToName = new Map(rows.map((r) => [r.id, r.name]));
  return ids.map((id) => idToName.get(id) ?? id);
}

async function enrichRecipe(recipe: any): Promise<any> {
  const obj = rewriteThumbnail(toSnake(recipe));
  if (obj.ingredients_without_measures && Array.isArray(obj.ingredients_without_measures)) {
    obj.ingredients_without_measures = await resolveIngredientNames(obj.ingredients_without_measures);
  }
  if (obj.tags && Array.isArray(obj.tags)) {
    obj.tags = await resolveTagNames(obj.tags);
  }
  return obj;
}

async function enrichRecipes(recipes: any[]): Promise<any[]> {
  // Batch resolve all IDs at once for efficiency
  const allIngIds = new Set<string>();
  const allTagIds = new Set<string>();
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  for (const r of recipes) {
    const ings = (r.ingredientsWithoutMeasures ?? r.ingredients_without_measures) as string[] | null;
    if (ings) ings.filter((id: string) => uuidPattern.test(id)).forEach((id: string) => allIngIds.add(id));
    const ts = (r.tags ?? r.tags) as string[] | null;
    if (ts) ts.filter((id: string) => uuidPattern.test(id)).forEach((id: string) => allTagIds.add(id));
  }

  let ingIdToName = new Map<string, string>();
  if (allIngIds.size > 0) {
    const rows = await db
      .select({ id: ingredients.id, name: ingredients.name })
      .from(ingredients)
      .where(inArray(ingredients.id, [...allIngIds]));
    ingIdToName = new Map(rows.map((r) => [r.id, r.name]));
  }

  let tagIdToName = new Map<string, string>();
  if (allTagIds.size > 0) {
    const rows = await db
      .select({ id: tags.id, name: tags.name })
      .from(tags)
      .where(inArray(tags.id, [...allTagIds]));
    tagIdToName = new Map(rows.map((r) => [r.id, r.name]));
  }

  return recipes.map((r) => {
    const obj = rewriteThumbnail(toSnake(r));
    if (obj.ingredients_without_measures && Array.isArray(obj.ingredients_without_measures)) {
      obj.ingredients_without_measures = obj.ingredients_without_measures.map(
        (id: string) => ingIdToName.get(id) ?? id
      );
    }
    if (obj.tags && Array.isArray(obj.tags)) {
      obj.tags = obj.tags.map(
        (id: string) => tagIdToName.get(id) ?? id
      );
    }
    return obj;
  });
}

async function ensureCreator(username: string | null | undefined, platform: "instagram" | "tiktok" | "x" | "nefisyemektarifleri" | "other") {
  if (!username || username === "unknown") return;
  const trimmed = username.trim().toLowerCase();
  if (!trimmed) return;

  const existing = await db
    .select()
    .from(platformCreators)
    .where(eq(platformCreators.username, trimmed))
    .limit(1);

  if (existing.length > 0 && existing[0].profilePictureUrl) return;

  let profilePictureUrl: string | null = null;
  let displayName: string | null = null;

  try {
    if (platform === "instagram") {
      const res = await fetch(`https://www.instagram.com/${trimmed}/`, {
        headers: { "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15" },
      });
      const html = await res.text();
      const match = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)
        || html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
      if (match?.[1]) {
        const picUrl = match[1].replace(/&amp;/g, "&");
        // Skip generic Instagram logo — real profile pics come from scontent/fbcdn CDNs
        const isRealProfilePic = picUrl.includes("scontent") || picUrl.includes("fbcdn");
        if (isRealProfilePic) {
          const picRes = await fetch(picUrl);
          if (picRes.ok) {
            const buffer = Buffer.from(await picRes.arrayBuffer());
            profilePictureUrl = await uploadImage(buffer.toString("base64"));
          }
        }
      }
    } else if (platform === "tiktok") {
      // Use oEmbed to get author info
      const res = await fetch(`https://www.tiktok.com/oembed?url=https://www.tiktok.com/@${trimmed}`);
      if (res.ok) {
        const data = await res.json() as any;
        displayName = data.author_name || null;
        if (data.author_thumbnail_url) {
          const picRes = await fetch(data.author_thumbnail_url);
          if (picRes.ok) {
            const buffer = Buffer.from(await picRes.arrayBuffer());
            profilePictureUrl = await uploadImage(buffer.toString("base64"));
          }
        }
      }
    }
    if (profilePictureUrl) console.log(`Fetched profile picture for @${trimmed} (${platform})`);
  } catch {
    console.log(`Could not fetch profile picture for @${trimmed} (${platform})`);
  }

  if (existing.length > 0) {
    const updates: Record<string, any> = {};
    if (profilePictureUrl) updates.profilePictureUrl = profilePictureUrl;
    if (displayName) updates.displayName = displayName;
    if (Object.keys(updates).length > 0) {
      await db.update(platformCreators).set(updates).where(eq(platformCreators.username, trimmed));
    }
  } else {
    await db
      .insert(platformCreators)
      .values({ username: trimmed, platform, displayName, profilePictureUrl })
      .onConflictDoNothing();
  }
}

// Check if recipe already exists for this URL
app.get("/recipes/lookup", async (req, res) => {
  const url = req.query.url as string;
  if (!url) {
    res.status(400).json({ error: "url query parameter required" });
    return;
  }

  const result = await db
    .select()
    .from(recipes)
    .where(eq(recipes.url, url))
    .limit(1);

  if (result.length === 0) {
    res.json(null);
    return;
  }

  res.json(await enrichRecipe(result[0]));
});

// Save a new recipe
app.post("/recipes", async (req, res) => {
  const data = req.body;

  // Return existing if URL already saved
  const existing = await db
    .select()
    .from(recipes)
    .where(eq(recipes.url, data.url))
    .limit(1);

  if (existing.length > 0) {
    // Recipe already processed — just add user mapping
    if (data.user_id) {
      await db
        .insert(userRecipes)
        .values({ userId: data.user_id, recipeId: existing[0].id })
        .onConflictDoNothing();
      console.log(`  -> Already exists, added mapping for user ${data.user_id}`);
    } else {
      console.log(`  -> Already exists, returning cached`);
    }
    res.json(await enrichRecipe(existing[0]));
    return;
  }

  const meta = parseCaptionMeta(data.caption);
  console.log(`  -> Parsed caption: user=${meta.platformUser}, likes=${meta.likesCount}, comments=${meta.commentsCount}`);

  // Upload thumbnail to S3 if provided
  let thumbnailUrl: string | null = null;
  if (data.thumbnail_base64) {
    try {
      thumbnailUrl = await uploadImage(data.thumbnail_base64);
      console.log(`Uploaded thumbnail: ${thumbnailUrl}`);
    } catch (err) {
      console.error("S3 upload failed:", err);
    }
  }

  // Ensure instagram user exists before inserting recipe (FK)
  const creatorUsername = data.platform_user || meta.platformUser || extractUserFromURL(data.url) || "unknown";
  await ensureCreator(creatorUsername, data.platform);

  const result = await db
    .insert(recipes)
    .values({
      platform: data.platform,
      platformUser: data.platform_user || meta.platformUser || extractUserFromURL(data.url) || "unknown",
      url: data.url,
      likesCount: data.likes_count || meta.likesCount || 0,
      commentsCount: data.comments_count || meta.commentsCount || 0,
      caption: data.caption,
      title: data.title,
      description: data.description,
      ingredientsWithMeasures: data.ingredients_with_measures ?? [],
      ingredientsWithoutMeasures: await resolveIngredientIds(data.ingredients_without_measures ?? []),
      thumbnailUrl,
      servings: data.servings,
      caloriesTotalKcal: data.calories_total_kcal,
      caloriesTotalJoules: data.calories_total_joules,
      caloriesPerServingKcal: data.calories_per_serving_kcal,
      proteinGrams: data.protein_grams,
      carbsGrams: data.carbs_grams,
      fatGrams: data.fat_grams,
      fiberGrams: data.fiber_grams,
      tags: await resolveTagIds((data.tags ?? []).filter((t: string) => PREDEFINED_TAGS.includes(t))),
      cookingTimeMinutes: data.cooking_time_minutes ?? parseCookingTime(data.cooking_time) ?? 30,
      cuisine: data.cuisine,
      difficulty: data.difficulty,
      freezerFriendly: data.freezer_friendly ?? false,
      healthScore: data.health_score,
      requestedBy: data.requested_by,
    })
    .returning();

  // Add user-recipe mapping
  if (data.user_id) {
    await db
      .insert(userRecipes)
      .values({ userId: data.user_id, recipeId: result[0].id })
      .onConflictDoNothing();
  }

  console.log(`  -> Saved: ${result[0].title} (thumbnail: ${thumbnailUrl ? "YES" : "NO"})`);
  res.status(201).json(toSnake(result[0]));
});

// List recipes (optional filters: requested_by, platform)
app.get("/recipes", async (req, res) => {
  let query = db.select().from(recipes);

  const conditions = [];
  if (req.query.requested_by) {
    conditions.push(eq(recipes.requestedBy, req.query.requested_by as string));
  }
  if (req.query.platform) {
    conditions.push(
      eq(recipes.platform, req.query.platform as "instagram" | "tiktok" | "x" | "nefisyemektarifleri" | "other")
    );
  }

  const result = conditions.length > 0
    ? await query.where(conditions[0]).orderBy(desc(recipes.createdAt))
    : await query.orderBy(desc(recipes.createdAt));

  res.json(await enrichRecipes(result));
});

// Get recipes for a user (includes folder info)
app.get("/users/:userId/recipes", async (req, res) => {
  const mappings = await db
    .select({
      recipeId: userRecipes.recipeId,
      folderId: userRecipes.folderId,
      isFavorite: userRecipes.isFavorite,
    })
    .from(userRecipes)
    .where(eq(userRecipes.userId, req.params.userId));

  if (mappings.length === 0) {
    res.json([]);
    return;
  }

  const recipeIds = mappings.map((m) => m.recipeId);
  const result = await db
    .select()
    .from(recipes)
    .where(inArray(recipes.id, recipeIds))
    .orderBy(desc(recipes.createdAt));

  // Attach folder_id and is_favorite to each recipe
  const folderMap = new Map(mappings.map((m) => [m.recipeId, m.folderId]));
  const favoriteMap = new Map(mappings.map((m) => [m.recipeId, m.isFavorite]));
  const enriched = result.map((r) => ({
    ...r,
    folderId: folderMap.get(r.id) ?? null,
    isFavorite: favoriteMap.get(r.id) ?? false,
  }));

  res.json(await enrichRecipes(enriched));
});

// Get single recipe
app.get("/recipes/:id", async (req, res) => {
  const result = await db
    .select()
    .from(recipes)
    .where(eq(recipes.id, req.params.id))
    .limit(1);

  if (result.length === 0) {
    res.status(404).json({ error: "Tarif bulunamadı" });
    return;
  }

  res.json(await enrichRecipe(result[0]));
});

// Backfill missing metadata from captions
app.post("/recipes/backfill", async (_req, res) => {
  const all = await db.select().from(recipes);
  let updated = 0;

  for (const recipe of all) {
    const meta = parseCaptionMeta(recipe.caption);
    const updates: Record<string, any> = {};

    if (!recipe.platformUser && meta.platformUser) updates.platformUser = meta.platformUser;
    if (!recipe.likesCount && meta.likesCount) updates.likesCount = meta.likesCount;
    if (!recipe.commentsCount && meta.commentsCount) updates.commentsCount = meta.commentsCount;

    if (Object.keys(updates).length > 0) {
      await db.update(recipes).set(updates).where(eq(recipes.id, recipe.id));
      updated++;
    }
  }

  // Also resolve ingredient IDs from existing recipes
  for (const recipe of all) {
    const ings = recipe.ingredientsWithoutMeasures as string[] | null;
    if (ings && ings.length > 0) {
      const ids = await resolveIngredientIds(ings);
      await db.update(recipes).set({ ingredientsWithoutMeasures: ids }).where(eq(recipes.id, recipe.id));
    }
  }

  res.json({ backfilled: updated, total: all.length });
});

// Backfill freezer_friendly for existing recipes using AI
app.post("/recipes/backfill-freezer", async (_req, res) => {
  const all = await db.select().from(recipes);
  const enriched = await enrichRecipes(all);

  const toClassify = enriched.map((r: any) => ({
    id: r.id,
    title: r.title,
    tags: (r.tags as string[]) || [],
    ingredients: (r.ingredients_without_measures as string[]) || [],
  }));

  if (toClassify.length === 0) {
    res.json({ updated: 0, total: 0 });
    return;
  }

  console.log(`[Freezer] Classifying ${toClassify.length} recipes...`);

  try {
    // Process in batches of 20
    let updated = 0;
    for (let i = 0; i < toClassify.length; i += 20) {
      const batch = toClassify.slice(i, i + 20);
      const results = await classifyFreezerFriendly(batch);

      for (const item of results) {
        await db
          .update(recipes)
          .set({ freezerFriendly: item.freezer_friendly })
          .where(eq(recipes.id, item.id));
        updated++;
      }

      console.log(`[Freezer] Batch ${Math.floor(i / 20) + 1}: ${results.length} classified`);
    }

    console.log(`[Freezer] Updated ${updated}/${toClassify.length} recipes`);
    res.json({ updated, total: toClassify.length });
  } catch (err: any) {
    console.error("[Freezer]", err.message || err);
    res.status(500).json({ error: "Freezer classification failed", detail: err.message });
  }
});

// Sync Clerk user to local DB
app.post("/users/sync", async (req, res) => {
  const { clerk_id, email, name, avatar_url } = req.body;

  if (!clerk_id) {
    res.status(400).json({ error: "clerk_id required" });
    return;
  }

  const existing = await db
    .select()
    .from(users)
    .where(eq(users.clerkId, clerk_id))
    .limit(1);

  if (existing.length > 0) {
    await db
      .update(users)
      .set({ email, name, avatarUrl: avatar_url })
      .where(eq(users.clerkId, clerk_id));
  } else {
    await db
      .insert(users)
      .values({ clerkId: clerk_id, email, name, avatarUrl: avatar_url });
  }

  res.json({ ok: true });
});

// List all known ingredients (with price tier and price)
app.get("/ingredients", async (_req, res) => {
  const result = await db
    .select()
    .from(ingredients)
    .orderBy(ingredients.name);
  res.json(result.map((r) => ({
    name: r.name,
    price_tier: r.priceTier,
    availability: r.availability,
    price_per_unit: r.pricePerUnit,
    price_unit: r.priceUnit,
    price_updated_at: r.priceUpdatedAt,
    default_unit: r.defaultUnit,
    density_g_ml: r.densityGMl,
    gram_per_adet: r.gramPerAdet,
  })));
});

// Update price tier for an ingredient
app.put("/ingredients/:name/price-tier", async (req, res) => {
  const { price_tier } = req.body;
  if (!["cheap", "neutral", "expensive"].includes(price_tier)) {
    res.status(400).json({ error: "price_tier must be cheap, neutral, or expensive" });
    return;
  }

  const result = await db
    .update(ingredients)
    .set({ priceTier: price_tier })
    .where(eq(ingredients.name, req.params.name))
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "Ingredient not found" });
    return;
  }

  res.json({ name: result[0].name, price_tier: result[0].priceTier, availability: result[0].availability });
});

// Update availability for an ingredient
app.put("/ingredients/:name/availability", async (req, res) => {
  const { availability } = req.body;
  if (!["easy", "neutral", "rare"].includes(availability)) {
    res.status(400).json({ error: "availability must be easy, neutral, or rare" });
    return;
  }

  const result = await db
    .update(ingredients)
    .set({ availability })
    .where(eq(ingredients.name, req.params.name))
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "Ingredient not found" });
    return;
  }

  res.json({ name: result[0].name, price_tier: result[0].priceTier, availability: result[0].availability });
});

// Classify all unclassified ingredients using Claude
app.post("/ingredients/classify", async (_req, res) => {
  // Fetch ingredients missing price_tier or availability
  const all = await db.select().from(ingredients).orderBy(ingredients.name);
  const unclassified = all.filter((r) => !r.priceTier || !r.availability);

  if (unclassified.length === 0) {
    res.json({ classified: 0, total: all.length, message: "All ingredients already classified" });
    return;
  }

  const names = unclassified.map((r) => r.name);
  console.log(`[Classify] Sending ${names.length} ingredients to Claude...`);

  try {
    const results = await classifyIngredients(names);
    let updated = 0;

    for (const item of results) {
      const match = unclassified.find((r) => r.name.toLowerCase() === item.name.toLowerCase());
      if (!match) continue;

      const updates: Record<string, string> = {};
      if (!match.priceTier && ["cheap", "neutral", "expensive"].includes(item.price_tier)) {
        updates.priceTier = item.price_tier;
      }
      if (!match.availability && ["easy", "neutral", "rare"].includes(item.availability)) {
        updates.availability = item.availability;
      }

      if (Object.keys(updates).length > 0) {
        await db.update(ingredients).set(updates).where(eq(ingredients.name, match.name));
        updated++;
      }
    }

    console.log(`[Classify] Updated ${updated}/${names.length} ingredients`);
    res.json({ classified: updated, total: all.length, sent: names.length });
  } catch (err: any) {
    console.error("[Classify]", err.message || err);
    res.status(500).json({ error: "Classification failed", detail: err.message });
  }
});

// Consolidate ingredients: capitalize first letter with proper Turkish characters, merge duplicates
app.post("/ingredients/consolidate", async (_req, res) => {
  try {
    const all = await db.select().from(ingredients).orderBy(ingredients.name);
    console.log(`[Consolidate] Processing ${all.length} ingredients...`);

    // Group by normalized (capitalized Turkish) name
    const groups = new Map<string, typeof all>();
    for (const row of all) {
      const canonical = fixTurkish(row.name);
      if (!groups.has(canonical)) groups.set(canonical, []);
      groups.get(canonical)!.push(row);
    }

    let renamed = 0;
    let merged = 0;

    for (const [canonical, rows] of groups) {
      if (rows.length === 1) {
        // Just rename if needed
        if (rows[0].name !== canonical) {
          await db.update(ingredients).set({ name: canonical }).where(eq(ingredients.id, rows[0].id));
          console.log(`  Renamed: "${rows[0].name}" -> "${canonical}"`);
          renamed++;
        }
      } else {
        // Merge duplicates: keep the first one (prefer one with classification data)
        const sorted = rows.sort((a, b) => {
          const aScore = (a.priceTier ? 1 : 0) + (a.availability ? 1 : 0) + (a.pricePerUnit ? 1 : 0);
          const bScore = (b.priceTier ? 1 : 0) + (b.availability ? 1 : 0) + (b.pricePerUnit ? 1 : 0);
          return bScore - aScore;
        });
        const keep = sorted[0];
        const dupes = sorted.slice(1);
        const dupeIds = dupes.map((d) => d.id);

        // Update references in userPantry
        await db.update(userPantry)
          .set({ ingredientId: keep.id })
          .where(inArray(userPantry.ingredientId, dupeIds));

        // Update references in userShoppingList
        await db.update(userShoppingList)
          .set({ ingredientId: keep.id })
          .where(inArray(userShoppingList.ingredientId, dupeIds));

        // Update jsonb arrays in recipes.ingredients_without_measures
        for (const dupe of dupes) {
          await db.execute(sql`
            UPDATE recipes
            SET ingredients_without_measures = (
              SELECT jsonb_agg(
                CASE WHEN elem = ${dupe.id}::text THEN ${keep.id}::text ELSE elem END
              )
              FROM jsonb_array_elements_text(ingredients_without_measures) AS elem
            )
            WHERE ingredients_without_measures::text LIKE ${"%" + dupe.id + "%"}
          `);
        }

        // Delete duplicates
        await db.delete(ingredients).where(inArray(ingredients.id, dupeIds));

        // Rename the kept one
        if (keep.name !== canonical) {
          await db.update(ingredients).set({ name: canonical }).where(eq(ingredients.id, keep.id));
        }

        console.log(`  Merged: [${rows.map((r) => `"${r.name}"`).join(", ")}] -> "${canonical}" (kept ${keep.id})`);
        merged += dupes.length;
        renamed++;
      }
    }

    console.log(`[Consolidate] Done: ${renamed} renamed, ${merged} duplicates merged`);
    res.json({ renamed, merged, total: all.length, remaining: groups.size });
  } catch (err: any) {
    console.error("[Consolidate]", err.message || err);
    res.status(500).json({ error: "Consolidation failed", detail: err.message });
  }
});

// Fetch real prices from marketfiyati.org.tr for all ingredients
// Uses https module directly because the TUBITAK SSL cert isn't in Node's trust store
const marketAgent = new https.Agent({ rejectUnauthorized: false });

function marketFetch(keyword: string): Promise<any> {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ keywords: keyword, pages: 0, size: 10 });
    const req = https.request(
      {
        hostname: "api.marketfiyati.org.tr",
        path: "/api/v2/search",
        method: "POST",
        agent: marketAgent,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Origin": "https://marketfiyati.org.tr",
          "Referer": "https://marketfiyati.org.tr/",
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}`));
          try { resolve(JSON.parse(data)); } catch { reject(new Error("Invalid JSON")); }
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

async function searchMarketPrice(keyword: string): Promise<{ pricePerUnit: number; priceUnit: string } | null> {
  try {
    const data = await marketFetch(keyword);
    if (!data.content?.length) return null;

    // Find cheapest unit price across all results
    let bestPrice = Infinity;
    let bestUnit = "Kg";

    for (const product of data.content) {
      for (const depot of product.productDepotInfoList ?? []) {
        if (depot.unitPriceValue && depot.unitPriceValue < bestPrice) {
          bestPrice = depot.unitPriceValue;
          // Extract unit from "56,43 ₺/Kg" -> "Kg"
          const unitMatch = depot.unitPrice?.match(/₺\/(.+)/);
          bestUnit = unitMatch?.[1] ?? "Kg";
        }
      }
    }

    if (bestPrice === Infinity) return null;
    return { pricePerUnit: Math.round(bestPrice * 100) / 100, priceUnit: bestUnit };
  } catch (err: any) {
    console.log(`    [API] ${keyword}: ${err.message}`);
    return null;
  }
}

app.post("/ingredients/fetch-prices", async (req, res) => {
  const forceAll = req.query.force === "true";
  const all = await db.select().from(ingredients).orderBy(ingredients.name);
  const toFetch = forceAll ? all : all.filter((r) => !r.pricePerUnit);

  if (toFetch.length === 0) {
    res.json({ updated: 0, failed: 0, total: all.length, message: "All ingredients already have prices" });
    return;
  }

  let updated = 0;
  let failed = 0;

  console.log(`[Prices] Fetching prices for ${toFetch.length}/${all.length} ingredients from marketfiyati.org.tr...`);

  for (const ing of toFetch) {
    const result = await searchMarketPrice(ing.name);
    if (result) {
      await db
        .update(ingredients)
        .set({
          pricePerUnit: result.pricePerUnit,
          priceUnit: result.priceUnit,
          priceUpdatedAt: new Date(),
        })
        .where(eq(ingredients.id, ing.id));
      updated++;
      console.log(`  ${ing.name}: ${result.pricePerUnit} ₺/${result.priceUnit}`);
    } else {
      failed++;
      console.log(`  ${ing.name}: not found`);
    }

    // Rate limit: delay between requests to avoid 403
    await new Promise((r) => setTimeout(r, 500));
  }

  console.log(`[Prices] Updated ${updated}/${toFetch.length} (${failed} not found)`);
  res.json({ updated, failed, total: all.length, fetched: toFetch.length });
});

// Estimate cost of a recipe based on ingredient prices
app.get("/recipes/:id/cost", async (req, res) => {
  const recipe = await db
    .select()
    .from(recipes)
    .where(eq(recipes.id, req.params.id))
    .limit(1);

  if (recipe.length === 0) {
    res.status(404).json({ error: "Tarif bulunamadı" });
    return;
  }

  const ingredientIds = recipe[0].ingredientsWithoutMeasures as string[] | null;
  const recipeIngsWithMeasures = recipe[0].ingredientsWithMeasures as { name: string; amount: string }[] | null;

  if (!ingredientIds || ingredientIds.length === 0) {
    res.json({ estimated_cost: null, ingredients: [] });
    return;
  }

  // Fetch ingredients by ID (they're UUIDs now)
  const priced = await db
    .select()
    .from(ingredients)
    .where(inArray(ingredients.id, ingredientIds));

  const priceMap = new Map(priced.map((p) => [p.id, p]));
  let totalCost = 0;
  let pricedCount = 0;

  const breakdown = ingredientIds.map((id, i) => {
    const ing = priceMap.get(id);
    const measure = recipeIngsWithMeasures?.[i]?.amount ?? null;
    const name = ing?.name ?? id;

    if (ing?.pricePerUnit) {
      pricedCount++;
      const isPerAdet = ing.priceUnit === "Adet";
      // Estimate quantity in price_unit from measure string
      let estimatedQty = isPerAdet ? 1 : 0.15; // default: 1 unit or 150g
      if (measure) {
        const lower = measure.toLowerCase();
        // Handle fractions like "1/2", "1/4"
        let val = 1;
        const fracMatch = lower.match(/([\d.,]+)\s*\/\s*([\d.,]+)/);
        const numMatch = lower.match(/([\d.,]+)/);
        if (fracMatch) {
          val = parseFloat(fracMatch[1].replace(",", ".")) / parseFloat(fracMatch[2].replace(",", "."));
        } else if (numMatch) {
          val = parseFloat(numMatch[1].replace(",", "."));
        }

        if (lower.includes("kg")) estimatedQty = val;
        else if (lower.includes("gr") || lower.includes("gram") || /\d+\s*g\b/.test(lower)) estimatedQty = val / 1000;
        else if (lower.includes("lt") || lower.includes("litre")) estimatedQty = val;
        else if (lower.includes("ml")) estimatedQty = val / 1000;
        else if (lower.includes("su bardağı") || lower.includes("su bardagi")) estimatedQty = val * 0.2; // ~200ml
        else if (lower.includes("çay bardağı")) estimatedQty = val * 0.1;
        else if (lower.includes("bardak")) estimatedQty = val * 0.2;
        else if (lower.includes("çay kaşığı") || lower.includes("tatlı kaşığı")) estimatedQty = val * 0.005;
        else if (lower.includes("yemek kaşığı") || lower.includes("kaşık")) estimatedQty = val * 0.015;
        else if (lower.includes("tutam") || lower.includes("çimdik")) estimatedQty = val * 0.002;
        else if (lower.includes("adet") || lower.includes("tane") || lower.includes("diş") || lower.includes("dal") || lower.includes("demet") || lower.includes("dilim")) {
          estimatedQty = isPerAdet ? val : val * 0.05;
        } else {
          estimatedQty = isPerAdet ? val : (val > 10 ? val / 1000 : val * 0.05);
        }
      }
      const cost = Math.round(ing.pricePerUnit * estimatedQty * 100) / 100;
      totalCost += cost;
      return { name, measure, price_per_unit: ing.pricePerUnit, price_unit: ing.priceUnit, estimated_qty: estimatedQty, estimated_cost: cost };
    }
    return { name, measure, price_per_unit: null, price_unit: null, estimated_qty: null, estimated_cost: null };
  });

  res.json({
    estimated_cost: Math.round(totalCost * 100) / 100,
    currency: "TRY",
    priced_count: pricedCount,
    total_count: ingredientIds.length,
    ingredients: breakdown,
  });
});

// Proxy S3 images
app.get("/images/:folder/:file", async (req, res) => {
  const key = `${req.params.folder}/${req.params.file}`;
  const data = await getImage(key);
  if (!data) {
    res.status(404).json({ error: "Image not found" });
    return;
  }
  res.setHeader("Content-Type", "image/jpeg");
  res.setHeader("Cache-Control", "public, max-age=86400");
  res.send(data);
});

// Delete recipe
app.delete("/recipes/:id", async (req, res) => {
  const result = await db
    .delete(recipes)
    .where(eq(recipes.id, req.params.id))
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "Tarif bulunamadı" });
    return;
  }

  res.status(204).send();
});

// Fix Turkish characters in existing ingredients and recipes
app.post("/recipes/fix-turkish", async (_req, res) => {
  // 1. Fix ingredients table
  const allIngs = await db.select().from(ingredients);
  let ingFixed = 0;
  for (const ing of allIngs) {
    const fixed = fixTurkish(ing.name);
    if (fixed !== ing.name) {
      // Check if the fixed name already exists
      const existing = await db
        .select()
        .from(ingredients)
        .where(eq(ingredients.name, fixed))
        .limit(1);

      if (existing.length > 0) {
        // Fixed name already exists, delete the old one
        await db.delete(ingredients).where(eq(ingredients.id, ing.id));
      } else {
        await db
          .update(ingredients)
          .set({ name: fixed })
          .where(eq(ingredients.id, ing.id));
      }
      ingFixed++;
    }
  }

  // 2. Re-resolve ingredient IDs in recipes (in case names changed)
  const allRecipes = await db.select().from(recipes);
  let recipeFixed = 0;
  for (const recipe of allRecipes) {
    const ings = recipe.ingredientsWithoutMeasures as string[] | null;
    if (!ings || ings.length === 0) continue;

    // Skip if already UUIDs
    const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-/i;
    if (ings[0] && uuidPattern.test(ings[0])) continue;

    const ids = await resolveIngredientIds(ings);
    if (ids.length > 0) {
      await db
        .update(recipes)
        .set({ ingredientsWithoutMeasures: ids })
        .where(eq(recipes.id, recipe.id));
      recipeFixed++;
    }
  }

  console.log(`Fixed Turkish: ${ingFixed} ingredients, ${recipeFixed} recipes`);
  res.json({ ingredientsFixed: ingFixed, recipesFixed: recipeFixed });
});

// Get creator info
app.get("/creators/:username", async (req, res) => {
  const result = await db
    .select()
    .from(platformCreators)
    .where(eq(platformCreators.username, req.params.username.toLowerCase()))
    .limit(1);

  if (result.length === 0) {
    res.status(404).json({ error: "Creator not found" });
    return;
  }

  let user = result[0];

  // If creator has no profile picture, fetch it before responding
  if (!user.profilePictureUrl) {
    try {
      await ensureCreator(user.username, user.platform);
      // Re-fetch to get the updated profile picture URL
      const updated = await db
        .select()
        .from(platformCreators)
        .where(eq(platformCreators.username, req.params.username.toLowerCase()))
        .limit(1);
      if (updated.length > 0) {
        user = updated[0];
      }
    } catch {}
  }

  res.json({
    username: user.username,
    platform: user.platform,
    display_name: user.displayName,
    profile_picture_url: user.profilePictureUrl
      ? s3KeyFromUrl(user.profilePictureUrl)
        ? `/images/${s3KeyFromUrl(user.profilePictureUrl)}`
        : user.profilePictureUrl
      : null,
  });
});

// --- Folders ---

// List user's folders with recipe counts
app.get("/users/:userId/folders", async (req, res) => {
  const folders = await db
    .select()
    .from(userFolders)
    .where(eq(userFolders.userId, req.params.userId))
    .orderBy(userFolders.sortOrder);

  // Get recipe counts per folder
  const mappings = await db
    .select({ folderId: userRecipes.folderId, recipeId: userRecipes.recipeId })
    .from(userRecipes)
    .where(eq(userRecipes.userId, req.params.userId));

  const countMap = new Map<string, number>();
  for (const m of mappings) {
    if (m.folderId) {
      countMap.set(m.folderId, (countMap.get(m.folderId) || 0) + 1);
    }
  }

  const result = folders.map((f) => ({
    ...toSnake(f),
    recipe_count: countMap.get(f.id) || 0,
  }));

  res.json(result);
});

// Create folder
app.post("/folders", async (req, res) => {
  const { user_id, name, emoji } = req.body;
  if (!user_id || !name) {
    res.status(400).json({ error: "user_id and name required" });
    return;
  }

  // Get max sort order
  const existing = await db
    .select({ sortOrder: userFolders.sortOrder })
    .from(userFolders)
    .where(eq(userFolders.userId, user_id))
    .orderBy(desc(userFolders.sortOrder))
    .limit(1);

  const nextOrder = (existing[0]?.sortOrder ?? -1) + 1;

  const result = await db
    .insert(userFolders)
    .values({ userId: user_id, name, emoji: emoji || null, sortOrder: nextOrder })
    .returning();

  res.status(201).json({ ...toSnake(result[0]), recipe_count: 0 });
});

// Update folder
app.put("/folders/:id", async (req, res) => {
  const { name, emoji, sort_order } = req.body;
  const updates: Record<string, any> = {};
  if (name !== undefined) updates.name = name;
  if (emoji !== undefined) updates.emoji = emoji;
  if (sort_order !== undefined) updates.sortOrder = sort_order;

  const result = await db
    .update(userFolders)
    .set(updates)
    .where(eq(userFolders.id, req.params.id))
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "Folder not found" });
    return;
  }

  res.json(toSnake(result[0]));
});

// Delete folder (recipes become unfoldered, not deleted)
app.delete("/folders/:id", async (req, res) => {
  await db
    .update(userRecipes)
    .set({ folderId: null })
    .where(eq(userRecipes.folderId, req.params.id));

  await db.delete(userFolders).where(eq(userFolders.id, req.params.id));
  res.status(204).send();
});

// Delete recipe from user's collection (keeps global recipe)
app.delete("/users/:userId/recipes/:recipeId", async (req, res) => {
  const result = await db
    .delete(userRecipes)
    .where(
      and(
        eq(userRecipes.userId, req.params.userId),
        eq(userRecipes.recipeId, req.params.recipeId)
      )
    )
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "User recipe not found" });
    return;
  }

  res.status(204).send();
});

// Move recipe to folder (or remove from folder with folder_id: null)
app.put("/users/:userId/recipes/:recipeId/folder", async (req, res) => {
  const { folder_id } = req.body;

  const result = await db
    .update(userRecipes)
    .set({ folderId: folder_id || null })
    .where(
      and(
        eq(userRecipes.userId, req.params.userId),
        eq(userRecipes.recipeId, req.params.recipeId)
      )
    )
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "User recipe not found" });
    return;
  }

  res.json({ ok: true });
});

// Toggle favorite
app.put("/users/:userId/recipes/:recipeId/favorite", async (req, res) => {
  const { is_favorite } = req.body;

  const result = await db
    .update(userRecipes)
    .set({ isFavorite: is_favorite ?? false })
    .where(
      and(
        eq(userRecipes.userId, req.params.userId),
        eq(userRecipes.recipeId, req.params.recipeId)
      )
    )
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "User recipe not found" });
    return;
  }

  res.json({ ok: true, is_favorite: result[0].isFavorite });
});

// Save a meal plan
app.post("/meal-plans", async (req, res) => {
  const { user_id, name, plan, recipe_ids, shopping_list } = req.body;
  if (!user_id || !plan) {
    res.status(400).json({ error: "user_id and plan required" });
    return;
  }

  // Build shopping list from recipes if not explicitly provided
  const resolvedShoppingList: ShoppingListItem[] = shopping_list && shopping_list.length > 0
    ? shopping_list
    : await buildShoppingListFromRecipes(recipe_ids ?? []);

  const result = await db
    .insert(mealPlans)
    .values({
      userId: user_id,
      name: name || "Yemek Planı",
      plan,
      recipeIds: recipe_ids ?? [],
      shoppingList: resolvedShoppingList,
      shoppingIngredientIds: [],
    })
    .returning();

  res.status(201).json(toSnake(result[0]));
});

// Get user's meal plans (backfills old plans missing recipe_ids/shopping_list)
app.get("/users/:userId/meal-plans", async (req, res) => {
  const result = await db
    .select()
    .from(mealPlans)
    .where(eq(mealPlans.userId, req.params.userId))
    .orderBy(desc(mealPlans.createdAt));

  // Backfill old plans that have no shopping_list or recipe_ids
  for (const plan of result) {
    const planData = plan.plan as any;
    const shoppingListCol = plan.shoppingList as any[];
    const recipeIdsCol = plan.recipeIds as string[];

    // Detect if shopping_list needs migration: empty, or old string[] format
    const isOldFormat = shoppingListCol?.length > 0 && typeof shoppingListCol[0] === "string";
    const needsBackfill =
      ((!shoppingListCol || shoppingListCol.length === 0) && planData?.days) || isOldFormat;

    if (!needsBackfill) continue;

    try {
      // Ensure feslihan creator exists
      await db
        .insert(platformCreators)
        .values({ username: "feslihan", platform: "other", displayName: "Feslihan AI" })
        .onConflictDoNothing();

      // Build titleToId for existing user recipes
      const mappings = await db
        .select({ recipeId: userRecipes.recipeId })
        .from(userRecipes)
        .where(eq(userRecipes.userId, req.params.userId));
      const existingRecipeRows = mappings.length > 0
        ? await db.select().from(recipes).where(inArray(recipes.id, mappings.map(m => m.recipeId)))
        : [];
      const titleToId: Record<string, string> = {};
      for (const r of existingRecipeRows) {
        titleToId[r.title] = r.id;
      }

      // Create missing recipes and resolve IDs (only for plans that need recipe creation)
      if (!recipeIdsCol || recipeIdsCol.length === 0) {
        for (const day of planData.days ?? []) {
          for (const meal of day.meals ?? []) {
            if (!meal.name) continue;
            const parts = (meal.name as string).split("+").map((s: string) => s.trim());
            for (const title of parts) {
              if (titleToId[title]) continue;
              const ingNames: string[] = (meal.ingredients ?? []).map(
                (i: string) => i.charAt(0).toUpperCase() + i.slice(1)
              );
              const ingIds = await resolveIngredientIds(ingNames);
              const url = `ai://meal-plan/${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
              const [created] = await db
                .insert(recipes)
                .values({
                  platform: "other",
                  platformUser: "feslihan",
                  url,
                  title,
                  description: meal.description ?? "",
                  ingredientsWithMeasures: ingNames.map((n: string) => ({ name: n, amount: "" })),
                  ingredientsWithoutMeasures: ingIds,
                  caloriesTotalKcal: meal.calories ?? null,
                  cookingTimeMinutes: 30,
                  tags: [],
                  requestedBy: req.params.userId,
                })
                .returning();
              titleToId[title] = created.id;
              await db
                .insert(userRecipes)
                .values({ userId: req.params.userId, recipeId: created.id })
                .onConflictDoNothing();
            }
          }
        }
      }

      // Rebuild plan with recipe_ids
      const newDays = (planData.days ?? []).map((day: any) => ({
        day_name: day.day_name,
        meals: (day.meals ?? []).map((meal: any) => {
          if (meal.recipe_ids) return { meal_type: meal.meal_type, recipe_ids: meal.recipe_ids };
          const parts = (meal.name as string || "").split("+").map((s: string) => s.trim());
          const ids = parts.map((t: string) => titleToId[t]).filter(Boolean);
          return { meal_type: meal.meal_type, recipe_ids: ids };
        }),
      }));

      const allIds = recipeIdsCol?.length > 0
        ? recipeIdsCol
        : Object.values(titleToId);
      const newPlan = { days: newDays, avg_calories_per_day: planData.avg_calories_per_day };

      // Build shopping list from recipe ingredients
      const newShoppingList = await buildShoppingListFromRecipes(allIds);

      // Update DB
      await db
        .update(mealPlans)
        .set({
          plan: newPlan,
          recipeIds: allIds,
          shoppingList: newShoppingList,
        })
        .where(eq(mealPlans.id, plan.id));

      // Update in-memory for this response
      (plan as any).plan = newPlan;
      (plan as any).recipeIds = allIds;
      (plan as any).shoppingList = newShoppingList;
    } catch (err) {
      console.error(`[meal-plans backfill] Error for plan ${plan.id}:`, err);
    }
  }

  res.json(toSnake(result));
});

// Update a meal plan
app.put("/meal-plans/:id", async (req, res) => {
  try {
    const { name, plan, recipe_ids, shopping_list } = req.body;
    const updates: Record<string, any> = {};
    if (name !== undefined) updates.name = name;
    if (plan !== undefined) updates.plan = plan;
    if (recipe_ids !== undefined) updates.recipeIds = recipe_ids;
    if (shopping_list !== undefined) updates.shoppingList = shopping_list;

    // Auto-rebuild shopping list from recipes when recipe_ids change but no explicit shopping_list
    if (recipe_ids !== undefined && shopping_list === undefined) {
      updates.shoppingList = await buildShoppingListFromRecipes(recipe_ids);
    }

    if (Object.keys(updates).length === 0) {
      res.status(400).json({ error: "No fields to update" });
      return;
    }

    const result = await db
      .update(mealPlans)
      .set(updates)
      .where(eq(mealPlans.id, req.params.id))
      .returning();

    if (result.length === 0) {
      res.status(404).json({ error: "Plan not found" });
      return;
    }

    res.json(toSnake(result[0]));
  } catch (err) {
    console.error("[meal-plans PUT] Error:", err);
    res.status(500).json({ error: "Failed to update plan" });
  }
});

// Delete a meal plan
app.delete("/meal-plans/:id", async (req, res) => {
  await db.delete(mealPlans).where(eq(mealPlans.id, req.params.id));
  res.status(204).send();
});

// ── Recipe Reviews ─────────────────────────────────────────────────────

app.post("/recipes/:recipeId/reviews", async (req, res) => {
  try {
    const { user_id, rating, comment } = req.body;
    if (!user_id || !rating || rating < 1 || rating > 5) {
      res.status(400).json({ error: "user_id and rating (1-5) required" });
      return;
    }
    const result = await db.insert(recipeReviews).values({
      userId: user_id,
      recipeId: req.params.recipeId,
      rating,
      comment: comment || null,
    }).returning();
    res.json(toSnake(result[0]));
  } catch (err) {
    console.error("[reviews POST]", err);
    res.status(500).json({ error: "Failed to save review" });
  }
});

app.get("/recipes/:recipeId/reviews", async (req, res) => {
  const result = await db
    .select()
    .from(recipeReviews)
    .where(eq(recipeReviews.recipeId, req.params.recipeId))
    .orderBy(desc(recipeReviews.createdAt));
  res.json(toSnake(result));
});

// Get all recipes a user has tried (with their reviews)
app.get("/users/:userId/reviews", async (req, res) => {
  const result = await db
    .select()
    .from(recipeReviews)
    .where(eq(recipeReviews.userId, req.params.userId))
    .orderBy(desc(recipeReviews.createdAt));
  res.json(toSnake(result));
});

// Delete a review
app.delete("/reviews/:reviewId", async (req, res) => {
  const { user_id } = req.query;
  if (!user_id) {
    res.status(400).json({ error: "user_id query param required" });
    return;
  }
  const result = await db
    .delete(recipeReviews)
    .where(
      and(
        eq(recipeReviews.id, req.params.reviewId),
        eq(recipeReviews.userId, user_id as string)
      )
    )
    .returning();
  if (result.length === 0) {
    res.status(404).json({ error: "Review not found" });
    return;
  }
  res.json({ ok: true });
});

// ── Pantry ──────────────────────────────────────────────────────────────

app.get("/users/:userId/pantry", async (req, res) => {
  const rows = await db
    .select({
      id: userPantry.id,
      ingredient_id: ingredients.id,
      ingredient_name: ingredients.name,
      price_tier: ingredients.priceTier,
      availability: ingredients.availability,
      added_at: userPantry.addedAt,
    })
    .from(userPantry)
    .innerJoin(ingredients, eq(userPantry.ingredientId, ingredients.id))
    .where(eq(userPantry.userId, req.params.userId))
    .orderBy(desc(userPantry.addedAt));
  res.json(rows);
});

app.post("/users/:userId/pantry", async (req, res) => {
  const { ingredient_names } = req.body as { ingredient_names: string[] };
  if (!ingredient_names?.length) {
    return res.status(400).json({ error: "ingredient_names required" });
  }

  // Resolve names to IDs
  const lowered = ingredient_names.map((n) => n.toLowerCase());
  const found = await db
    .select({ id: ingredients.id, name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.name, ingredient_names));

  // Also try lowercase match, then strip parenthetical notes e.g. "Tereyağı(kalıp için)" -> "Tereyağı"
  const foundNames = new Set(found.map((f) => f.name));
  const missed = ingredient_names.filter((n) => !foundNames.has(n));
  if (missed.length > 0) {
    const allIngredients = await db.select({ id: ingredients.id, name: ingredients.name }).from(ingredients);
    for (const m of missed) {
      const stripped = m.replace(/\s*\(.*?\)\s*/g, "").trim();
      const match = allIngredients.find((i) => i.name.toLowerCase() === m.toLowerCase())
        ?? allIngredients.find((i) => i.name.toLowerCase() === stripped.toLowerCase());
      if (match) found.push(match);
    }
  }

  const ingredientIds = found.map((f) => f.id);
  if (ingredientIds.length === 0) {
    return res.status(201).json({ added: 0 });
  }

  // Filter out ingredients already in pantry
  const existing = await db
    .select({ ingredientId: userPantry.ingredientId })
    .from(userPantry)
    .where(
      and(
        eq(userPantry.userId, req.params.userId),
        inArray(userPantry.ingredientId, ingredientIds)
      )
    );
  const existingIds = new Set(existing.map((e) => e.ingredientId));
  const newIds = ingredientIds.filter((id) => !existingIds.has(id));

  if (newIds.length > 0) {
    await db.insert(userPantry).values(
      newIds.map((id) => ({
        userId: req.params.userId,
        ingredientId: id,
      }))
    );
  }
  res.status(201).json({ added: newIds.length });
});

app.delete("/users/:userId/pantry/:ingredientId", async (req, res) => {
  await db
    .delete(userPantry)
    .where(
      and(
        eq(userPantry.userId, req.params.userId),
        eq(userPantry.ingredientId, req.params.ingredientId)
      )
    );
  res.status(204).send();
});

// ── Shopping List ───────────────────────────────────────────────────────

app.get("/users/:userId/shopping-list", async (req, res) => {
  const rows = await db
    .select({
      id: userShoppingList.id,
      ingredient_id: ingredients.id,
      ingredient_name: ingredients.name,
      price_tier: ingredients.priceTier,
      availability: ingredients.availability,
      is_checked: userShoppingList.isChecked,
      added_at: userShoppingList.addedAt,
    })
    .from(userShoppingList)
    .innerJoin(ingredients, eq(userShoppingList.ingredientId, ingredients.id))
    .where(eq(userShoppingList.userId, req.params.userId))
    .orderBy(desc(userShoppingList.addedAt));
  res.json(rows);
});

app.post("/users/:userId/shopping-list", async (req, res) => {
  const { ingredient_names } = req.body as { ingredient_names: string[] };
  if (!ingredient_names?.length) {
    return res.status(400).json({ error: "ingredient_names required" });
  }

  // Resolve names to IDs
  const found = await db
    .select({ id: ingredients.id, name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.name, ingredient_names));

  const foundNames = new Set(found.map((f) => f.name));
  const missed = ingredient_names.filter((n) => !foundNames.has(n));
  if (missed.length > 0) {
    const allIngredients = await db.select({ id: ingredients.id, name: ingredients.name }).from(ingredients);
    for (const m of missed) {
      const stripped = m.replace(/\s*\(.*?\)\s*/g, "").trim();
      const match = allIngredients.find((i) => i.name.toLowerCase() === m.toLowerCase())
        ?? allIngredients.find((i) => i.name.toLowerCase() === stripped.toLowerCase());
      if (match) found.push(match);
    }
  }

  const ingredientIds = found.map((f) => f.id);
  if (ingredientIds.length === 0) {
    return res.status(201).json({ added: 0 });
  }

  // Filter out ingredients already in shopping list
  const existing = await db
    .select({ ingredientId: userShoppingList.ingredientId })
    .from(userShoppingList)
    .where(
      and(
        eq(userShoppingList.userId, req.params.userId),
        inArray(userShoppingList.ingredientId, ingredientIds)
      )
    );
  const existingIds = new Set(existing.map((e) => e.ingredientId));
  const newIds = ingredientIds.filter((id) => !existingIds.has(id));

  if (newIds.length > 0) {
    await db.insert(userShoppingList).values(
      newIds.map((id) => ({
        userId: req.params.userId,
        ingredientId: id,
      }))
    );
  }
  res.status(201).json({ added: newIds.length });
});

app.put("/users/:userId/shopping-list/:itemId/check", async (req, res) => {
  const { is_checked } = req.body as { is_checked: boolean };
  await db
    .update(userShoppingList)
    .set({ isChecked: is_checked })
    .where(
      and(
        eq(userShoppingList.id, req.params.itemId),
        eq(userShoppingList.userId, req.params.userId)
      )
    );
  res.json({ ok: true });
});

app.delete("/users/:userId/shopping-list/:itemId", async (req, res) => {
  await db
    .delete(userShoppingList)
    .where(
      and(
        eq(userShoppingList.id, req.params.itemId),
        eq(userShoppingList.userId, req.params.userId)
      )
    );
  res.status(204).send();
});

// List all predefined tags
app.get("/tags", async (_req, res) => {
  const result = await db.select().from(tags).orderBy(tags.name);
  res.json(result.map((r) => r.name));
});

// Scrape recipe from nefisyemektarifleri.com
app.post("/recipes/scrape-web", async (req, res) => {
  const { url } = req.body;
  if (!url || !url.includes("nefisyemektarifleri.com")) {
    res.status(400).json({ error: "Only nefisyemektarifleri.com URLs are supported" });
    return;
  }

  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "tr-TR,tr;q=0.9",
      },
    });

    if (!response.ok) {
      res.status(502).json({ error: `Failed to fetch page: ${response.status}` });
      return;
    }

    const html = await response.text();

    // Parse title from <h1>
    const titleMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
    const title = titleMatch ? decodeHTMLEntities(titleMatch[1].trim()) : "";

    // Parse servings & cooking time from article list items
    const servingsMatch = html.match(/([\d]+(?:-\d+)?)\s*Kişilik/i);
    const servings = servingsMatch ? parseInt(servingsMatch[1].split("-").pop()!) : null;

    const timeMatch = html.match(/([\d]+)dk\s*Hazırlık(?:,?\s*([\d]+)dk\s*Pişirme)?/i);
    let cookingTimeMinutes = 30;
    if (timeMatch) {
      cookingTimeMinutes = parseInt(timeMatch[1]) + (timeMatch[2] ? parseInt(timeMatch[2]) : 0);
    }

    // Parse ingredients: find all <li> inside the ingredients section
    const ingredientSectionMatch = html.match(
      /Malzemeler<\/h2>([\s\S]*?)<h2[^>]*>.*?Nasıl Yapılır/i
    );
    const ingredientsWithMeasures: { name: string; amount: string }[] = [];
    const baseIngredients: string[] = [];
    if (ingredientSectionMatch) {
      const ingSection = ingredientSectionMatch[1];
      const liRegex = /<li[^>]*>([^<]+)<\/li>/gi;
      let match;
      while ((match = liRegex.exec(ingSection)) !== null) {
        const raw = decodeHTMLEntities(match[1].trim());
        // Try to separate amount from name: "4 su bardağı un" -> amount: "4 su bardağı", name: "un"
        const parts = parseIngredientLine(raw);
        ingredientsWithMeasures.push(parts);
        baseIngredients.push(parts.name.toLowerCase());
      }
    }

    // Parse instructions: find all <li> inside the "Nasıl Yapılır" section
    const instructionSectionMatch = html.match(
      /Nasıl Yapılır\??\s*<\/h2>([\s\S]*?)(?:<h2|<div[^>]+class="[^"]*sharing)/i
    );
    let instructions = "";
    if (instructionSectionMatch) {
      const instSection = instructionSectionMatch[1];
      const liRegex = /<li[^>]*>([^<]+)<\/li>/gi;
      const steps: string[] = [];
      let match;
      while ((match = liRegex.exec(instSection)) !== null) {
        steps.push(decodeHTMLEntities(match[1].trim()));
      }
      instructions = steps.map((s, i) => `${i + 1}. ${s}`).join("\n");
    }

    // Parse thumbnail from og:image
    const ogImageMatch = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)
      ?? html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
    const thumbnailUrl = ogImageMatch ? ogImageMatch[1].replace(/&amp;/g, "&") : null;

    // Parse author
    const authorMatch = html.match(/<a[^>]+class="[^"]*author[^"]*"[^>]*>([^<]+)<\/a>/i)
      ?? html.match(/<link[^>]+rel=["']author["'][^>]+href=["'][^"']*\/u\/([^/]+)\//i);
    const platformUser = authorMatch ? decodeHTMLEntities(authorMatch[1].trim()) : null;

    // Parse tags from breadcrumb
    const tagMatches: string[] = [];
    const breadcrumbRegex = /kategori\/tarifler\/([^/"]+)/gi;
    let bMatch;
    while ((bMatch = breadcrumbRegex.exec(html)) !== null) {
      const tag = decodeURIComponent(bMatch[1]).replace(/-tarifleri$/i, "").replace(/-/g, " ");
      const mapped = PREDEFINED_TAGS.find((t) => tag.includes(t));
      if (mapped && !tagMatches.includes(mapped)) tagMatches.push(mapped);
    }

    // Determine difficulty based on cooking time and ingredient count
    const difficulty = cookingTimeMinutes <= 20 && ingredientsWithMeasures.length <= 8
      ? "low"
      : cookingTimeMinutes >= 60 || ingredientsWithMeasures.length >= 15
        ? "high"
        : "medium";

    // Build recipe text for Claude nutrition estimation
    const recipeText = `${title}\n${servings} kişilik\nMalzemeler:\n${ingredientsWithMeasures.map((i) => `${i.amount} ${i.name}`).join("\n")}\n\nYapılış:\n${instructions}`;

    // Use Claude for nutrition estimation
    let nutrition: any = {};
    try {
      nutrition = await analyzeNutrition(recipeText);
    } catch (err) {
      console.error("[Scrape] Nutrition estimation failed:", err);
    }

    // Determine freezer-friendliness from tags and title
    const freezerKeywords = ["mantı", "börek", "köfte", "dolma", "sarma", "çorba", "güveç", "pilav"];
    const freezerFriendly = freezerKeywords.some((kw) =>
      title.toLowerCase().includes(kw) || tagMatches.some((t) => t.includes(kw))
    );

    const result = {
      is_recipe: true,
      title,
      ingredients: ingredientsWithMeasures,
      base_ingredients: baseIngredients,
      instructions,
      cooking_time_minutes: cookingTimeMinutes,
      servings,
      calories_total_kcal: nutrition.calories_total_kcal ?? null,
      calories_per_serving_kcal: nutrition.calories_per_serving_kcal ?? null,
      protein_grams: nutrition.protein_grams ?? null,
      carbs_grams: nutrition.carbs_grams ?? null,
      fat_grams: nutrition.fat_grams ?? null,
      fiber_grams: nutrition.fiber_grams ?? null,
      difficulty,
      cuisine: "turkish",
      tags: tagMatches,
      freezer_friendly: freezerFriendly,
      platform_user: platformUser,
      thumbnail_url: thumbnailUrl,
      likes_count: 0,
      comments_count: 0,
    };

    console.log(`[Scrape] Parsed: ${title} (${ingredientsWithMeasures.length} ingredients, ${cookingTimeMinutes}dk)`);
    res.json(result);
  } catch (err: any) {
    console.error("[Scrape] Error:", err.message || err);
    res.status(500).json({ error: "Scraping failed", detail: err.message });
  }
});

function decodeHTMLEntities(str: string): string {
  return str
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_m, code) => String.fromCharCode(parseInt(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_m, code) => String.fromCharCode(parseInt(code, 16)));
}

function parseIngredientLine(raw: string): { name: string; amount: string } {
  // Patterns: "4 su bardağı un", "1 adet yumurta", "400 g kıyma", "Sarımsaklı yoğurt"
  const amountMatch = raw.match(
    /^([\d½¼¾⅓⅔.,/]+\s*(?:su bardağı|çay bardağı|yemek kaşığı|tatlı kaşığı|çay kaşığı|adet|kg|g|ml|lt|litre|paket|demet|diş|dal|dilim|avuç|tutam|bardak|fincan|kaşık|porsiyon|büyük|küçük|orta boy|orta)\s*)/i
  );
  if (amountMatch) {
    return {
      amount: amountMatch[1].trim(),
      name: raw.slice(amountMatch[0].length).trim(),
    };
  }
  // Simple number prefix: "2 adet soğan" already caught, try just number
  const simpleMatch = raw.match(/^([\d½¼¾⅓⅔.,/]+\s*)/);
  if (simpleMatch && raw.length > simpleMatch[0].length) {
    return {
      amount: simpleMatch[1].trim(),
      name: raw.slice(simpleMatch[0].length).trim(),
    };
  }
  // No amount (e.g. "Sarımsaklı yoğurt", "Kuru nane")
  return { amount: "", name: raw };
}

// Analyze recipe from video content
app.post("/ai/analyze", async (req, res) => {
  try {
    const result = await analyzeRecipe(req.body);
    res.json(result);
  } catch (err: any) {
    console.error("[AI Analyze]", err.stack || err.message || err);
    res.status(500).json({ error: "AI analysis failed", detail: err.message });
  }
});

// Generate meal plan
app.post("/ai/meal-plan", async (req, res) => {
  try {
    // Fetch user's recipes if user_id provided
    let availableRecipes: any[] = [];
    // Build title→id map for resolving recipe names to IDs
    const titleToId: Record<string, string> = {};
    if (req.body.user_id) {
      const mappings = await db
        .select({ recipeId: userRecipes.recipeId })
        .from(userRecipes)
        .where(eq(userRecipes.userId, req.body.user_id));

      if (mappings.length > 0) {
        const recipeIds = mappings.map((m) => m.recipeId);
        const userRecipeRows = await db
          .select()
          .from(recipes)
          .where(inArray(recipes.id, recipeIds));

        const resolvedRecipes = await enrichRecipes(userRecipeRows);
        for (const r of resolvedRecipes) {
          titleToId[(r as any).title] = (r as any).id;
        }
        availableRecipes = resolvedRecipes.map((r: any) => ({
          title: r.title,
          tags: r.tags as string[],
          cooking_time_minutes: r.cooking_time_minutes ?? 30,
          cuisine: r.cuisine,
          ingredients: r.ingredients_without_measures || [],
          freezer_friendly: r.freezer_friendly ?? false,
        }));
      }
    }

    const result = await generateMealPlan({
      ...req.body,
      available_recipes: availableRecipes,
    });

    // Shopping list will be built from saved recipes after they're created

    // Ensure "feslihan" platform creator exists for AI-generated recipes
    await db
      .insert(platformCreators)
      .values({ username: "feslihan", platform: "other", displayName: "Feslihan AI" })
      .onConflictDoNothing();

    // Collect all unique recipe titles from the AI plan
    const allMealEntries: { title: string; meal: any }[] = [];
    for (const day of result.days ?? []) {
      for (const meal of day.meals ?? []) {
        const parts = (meal.name as string).split("+").map((s: string) => s.trim());
        for (const title of parts) {
          if (!allMealEntries.find((e) => e.title === title)) {
            allMealEntries.push({ title, meal });
          }
        }
      }
    }

    // Resolve all ingredient names in one batch
    const allIngNames = new Set<string>();
    for (const entry of allMealEntries) {
      for (const ing of entry.meal.ingredients ?? []) {
        allIngNames.add(ing.charAt(0).toUpperCase() + ing.slice(1));
      }
    }
    const allIngIds = await resolveIngredientIds([...allIngNames]);

    // Create missing recipes in one batch
    const userId = req.body.user_id || "system";
    const newRecipeEntries = allMealEntries.filter((e) => !titleToId[e.title]);

    if (newRecipeEntries.length > 0) {
      const newRecipeValues = newRecipeEntries.map((entry) => {
        const ingNames: string[] = (entry.meal.ingredients ?? []).map(
          (ing: string) => ing.charAt(0).toUpperCase() + ing.slice(1)
        );
        return {
          platform: "other" as const,
          platformUser: "feslihan",
          url: `ai://meal-plan/${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
          title: entry.title,
          description: entry.meal.description ?? "",
          ingredientsWithMeasures: ingNames.map((n: string) => ({ name: n, amount: "" })),
          ingredientsWithoutMeasures: ingNames,
          caloriesTotalKcal: entry.meal.calories ?? null,
          cookingTimeMinutes: 30,
          tags: [],
          requestedBy: userId,
        };
      });

      const created = await db.insert(recipes).values(newRecipeValues).returning();

      for (let i = 0; i < created.length; i++) {
        titleToId[newRecipeEntries[i].title] = created[i].id;
      }

      // Link all new recipes to user
      if (req.body.user_id) {
        // Ensure user exists
        await db
          .insert(users)
          .values({ clerkId: req.body.user_id })
          .onConflictDoNothing();
        for (const r of created) {
          try {
            await db.insert(userRecipes).values({ userId: req.body.user_id, recipeId: r.id });
          } catch { /* ignore duplicates */ }
        }
      }
    }

    // Build response with real recipe IDs
    const allRecipeIds: string[] = [];
    const leanDays = (result.days ?? []).map((day: any) => ({
      day_name: day.day_name,
      meals: (day.meals ?? []).map((meal: any) => {
        const parts = (meal.name as string).split("+").map((s: string) => s.trim());
        const ids = parts
          .map((title: string) => titleToId[title])
          .filter(Boolean) as string[];
        for (const id of ids) {
          if (!allRecipeIds.includes(id)) allRecipeIds.push(id);
        }
        return { meal_type: meal.meal_type, recipe_ids: ids };
      }),
    }));

    // Build shopping list from saved recipe ingredients
    const shoppingList = await buildShoppingListFromRecipes(allRecipeIds);

    res.json({
      days: leanDays,
      shopping_list: shoppingList,
      avg_calories_per_day: result.avg_calories_per_day ?? null,
      recipe_ids: allRecipeIds,
    });
  } catch (err: any) {
    console.error("[AI MealPlan] ERROR:", err.stack || err.message || err);
    res.status(500).json({ error: "Meal plan generation failed", detail: err.message });
  }
});

// Copy one user's recipes to all other users
app.post("/admin/share-recipes", async (req, res) => {
  const { source_user_id } = req.body;
  if (!source_user_id) {
    res.status(400).json({ error: "source_user_id required" });
    return;
  }

  // Get all recipe IDs for the source user
  const sourceRecipes = await db
    .select({ recipeId: userRecipes.recipeId })
    .from(userRecipes)
    .where(eq(userRecipes.userId, source_user_id));

  if (sourceRecipes.length === 0) {
    res.status(404).json({ error: "No recipes found for source user" });
    return;
  }

  const recipeIds = sourceRecipes.map((r) => r.recipeId);

  // Get all users except the source
  const allUsers = await db.select({ clerkId: users.clerkId }).from(users);
  const targetUsers = allUsers.filter((u) => u.clerkId !== source_user_id);

  let created = 0;
  for (const user of targetUsers) {
    for (const recipeId of recipeIds) {
      await db
        .insert(userRecipes)
        .values({ userId: user.clerkId, recipeId })
        .onConflictDoNothing();
      created++;
    }
  }

  console.log(`[Admin] Shared ${recipeIds.length} recipes from ${source_user_id} to ${targetUsers.length} users (${created} mappings)`);
  res.json({
    source_user: source_user_id,
    recipes_count: recipeIds.length,
    target_users_count: targetUsers.length,
    mappings_created: created,
  });
});

// Map ALL recipes to ALL users
app.post("/admin/map-all-recipes", async (_req, res) => {
  const allRecipes = await db.select({ id: recipes.id }).from(recipes);
  const allUsers = await db.select({ clerkId: users.clerkId }).from(users);

  let created = 0;
  for (const user of allUsers) {
    for (const recipe of allRecipes) {
      await db
        .insert(userRecipes)
        .values({ userId: user.clerkId, recipeId: recipe.id })
        .onConflictDoNothing();
      created++;
    }
  }

  console.log(`[Admin] Mapped ${allRecipes.length} recipes to ${allUsers.length} users (${created} mappings)`);
  res.json({
    recipes_count: allRecipes.length,
    users_count: allUsers.length,
    mappings_created: created,
  });
});

// Fill missing profile pictures for all platform creators
app.post("/admin/fill-creator-pictures", async (_req, res) => {
  const creators = await db
    .select()
    .from(platformCreators)
    .where(isNull(platformCreators.profilePictureUrl));

  console.log(`[Admin] Found ${creators.length} creators without profile pictures`);

  let filled = 0;
  let failed = 0;
  for (const creator of creators) {
    try {
      await ensureCreator(creator.username, creator.platform);
      // Check if it was actually filled
      const updated = await db
        .select({ profilePictureUrl: platformCreators.profilePictureUrl })
        .from(platformCreators)
        .where(eq(platformCreators.username, creator.username))
        .limit(1);
      if (updated[0]?.profilePictureUrl) {
        filled++;
        console.log(`  [OK] ${creator.username}`);
      } else {
        failed++;
        console.log(`  [SKIP] ${creator.username} - no picture found`);
      }
    } catch (err) {
      failed++;
      console.log(`  [ERR] ${creator.username} - ${err}`);
    }
  }

  console.log(`[Admin] Done: ${filled} filled, ${failed} failed out of ${creators.length}`);
  res.json({ total: creators.length, filled, failed });
});

// Seed predefined tags on startup
async function seedTags() {
  const existing = await db.select({ name: tags.name }).from(tags);
  const existingNames = new Set(existing.map((r) => r.name));
  const newTags = PREDEFINED_TAGS.filter((t) => !existingNames.has(t));

  if (newTags.length > 0) {
    await db
      .insert(tags)
      .values(newTags.map((name) => ({ name })))
      .onConflictDoNothing();
    console.log(`Seeded ${newTags.length} new tag(s): ${newTags.join(", ")}`);
  }
}

const PORT = 3000;
app.listen(PORT, async () => {
  await seedTags();
  console.log(`Feslihan API running on http://localhost:${PORT}`);
});
