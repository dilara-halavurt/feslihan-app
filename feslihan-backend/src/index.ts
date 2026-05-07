import "dotenv/config";
import express from "express";
import { db } from "./db.js";
import { recipes, ingredients, tags, platformCreators, userRecipes, userFolders, users, mealPlans } from "./schema.js";
import { uploadImage, s3KeyFromUrl, getImage } from "./s3.js";
import { analyzeRecipe, generateMealPlan } from "./ai.js";
import { eq, desc, inArray, and } from "drizzle-orm";

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

const turkishFixMap: Record<string, string> = {
  sarimsak: "sarımsak",
  sogan: "soğan",
  kiyma: "kıyma",
  feslegen: "fesleğen",
  cilek: "çilek",
  salca: "salça",
  nisasta: "nişasta",
  "kirmizi biber": "kırmızı biber",
  "yesil biber": "yeşil biber",
  "taze sogan": "taze soğan",
  "kasar peyniri": "kaşar peyniri",
  yogurt: "yoğurt",
  sut: "süt",
  tereyagi: "tereyağı",
  zeytinyagi: "zeytinyağı",
  seker: "şeker",
  pirinc: "pirinç",
  havuc: "havuç",
  patlican: "patlıcan",
  fistik: "fıstık",
  ispanak: "ıspanak",
  "ton baligi": "ton balığı",
  "defne yapragi": "defne yaprağı",
  "tatli biber": "tatlı biber",
  "sarimsak tozu": "sarımsak tozu",
  "sogan tozu": "soğan tozu",
  "taze fasulye": "taze fasulye",
  misir: "mısır",
  pirasa: "pırasa",
  salatalik: "salatalık",
  seftali: "şeftali",
  kayisi: "kayısı",
  visne: "vişne",
  uzum: "üzüm",
  incir: "incir",
  "kabartma tozu": "kabartma tozu",
  "beyaz peynir": "beyaz peynir",
  "pul biber": "pul biber",
  cicek: "çiçek",
  corek: "çörek",
  "corek otu": "çörek otu",
  kuskus: "kuskus",
  "aci biber": "acı biber",
  susam: "susam",
  bugday: "buğday",
  cesnisi: "çeşnisi",
  sucuk: "sucuk",
  pastirma: "pastırma",
  corba: "çorba",
  borek: "börek",
  guvec: "güveç",
  kofte: "köfte",
  dolma: "dolma",
  tursu: "turşu",
  recel: "reçel",
  "antep fistigi": "antep fıstığı",
  "pudra sekeri": "pudra şekeri",
  lavash: "lavaş",
};

function fixTurkish(name: string): string {
  const lower = name.toLowerCase().trim();
  return turkishFixMap[lower] ?? lower;
}

async function registerIngredients(names: string[]) {
  if (!names || names.length === 0) return;

  const normalized = [...new Set(names.map((n) => fixTurkish(n)).filter(Boolean))];
  if (normalized.length === 0) return;

  const existing = await db
    .select({ name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.name, normalized));

  const existingNames = new Set(existing.map((r) => r.name));
  const newNames = normalized.filter((n) => !existingNames.has(n));

  if (newNames.length > 0) {
    await db
      .insert(ingredients)
      .values(newNames.map((name) => ({ name })))
      .onConflictDoNothing();
    console.log(`Registered ${newNames.length} new ingredient(s): ${newNames.join(", ")}`);
  }
}

async function ensureCreator(username: string | null | undefined, platform: "instagram" | "tiktok" | "x" | "other") {
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
        const picRes = await fetch(picUrl);
        if (picRes.ok) {
          const buffer = Buffer.from(await picRes.arrayBuffer());
          profilePictureUrl = await uploadImage(buffer.toString("base64"));
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

  res.json(rewriteThumbnail(toSnake(result[0])));
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
    res.json(rewriteThumbnail(toSnake(existing[0])));
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
      ingredientsWithoutMeasures: (data.ingredients_without_measures ?? []).map((n: string) => fixTurkish(n)),
      thumbnailUrl,
      servings: data.servings,
      caloriesTotalKcal: data.calories_total_kcal,
      caloriesTotalJoules: data.calories_total_joules,
      caloriesPerServingKcal: data.calories_per_serving_kcal,
      proteinGrams: data.protein_grams,
      carbsGrams: data.carbs_grams,
      fatGrams: data.fat_grams,
      fiberGrams: data.fiber_grams,
      tags: (data.tags ?? []).filter((t: string) => PREDEFINED_TAGS.includes(t)),
      cookingTimeMinutes: data.cooking_time_minutes ?? parseCookingTime(data.cooking_time) ?? 30,
      cuisine: data.cuisine,
      difficulty: data.difficulty,
      healthScore: data.health_score,
      requestedBy: data.requested_by,
    })
    .returning();

  // Register any new base ingredients
  await registerIngredients(data.ingredients_without_measures ?? []);

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
      eq(recipes.platform, req.query.platform as "instagram" | "tiktok" | "x" | "other")
    );
  }

  const result = conditions.length > 0
    ? await query.where(conditions[0]).orderBy(desc(recipes.createdAt))
    : await query.orderBy(desc(recipes.createdAt));

  res.json(rewriteThumbnail(toSnake(result)));
});

// Get recipes for a user (includes folder info)
app.get("/users/:userId/recipes", async (req, res) => {
  const mappings = await db
    .select({
      recipeId: userRecipes.recipeId,
      folderId: userRecipes.folderId,
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

  // Attach folder_id to each recipe
  const folderMap = new Map(mappings.map((m) => [m.recipeId, m.folderId]));
  const enriched = result.map((r) => ({
    ...r,
    folderId: folderMap.get(r.id) ?? null,
  }));

  res.json(rewriteThumbnail(toSnake(enriched)));
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

  res.json(rewriteThumbnail(toSnake(result[0])));
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

  // Also register ingredients from existing recipes
  for (const recipe of all) {
    const ings = recipe.ingredientsWithoutMeasures as string[] | null;
    if (ings && ings.length > 0) {
      await registerIngredients(ings);
    }
  }

  res.json({ backfilled: updated, total: all.length });
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

// List all known ingredients (with price tier)
app.get("/ingredients", async (_req, res) => {
  const result = await db
    .select()
    .from(ingredients)
    .orderBy(ingredients.name);
  res.json(result.map((r) => ({ name: r.name, price_tier: r.priceTier, availability: r.availability })));
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

  // 2. Fix ingredients_without_measures in recipes
  const allRecipes = await db.select().from(recipes);
  let recipeFixed = 0;
  for (const recipe of allRecipes) {
    const ings = recipe.ingredientsWithoutMeasures as string[] | null;
    if (!ings || ings.length === 0) continue;

    const fixedIngs = ings.map((n: string) => fixTurkish(n));
    const changed = fixedIngs.some((f: string, i: number) => f !== ings[i]);

    if (changed) {
      await db
        .update(recipes)
        .set({ ingredientsWithoutMeasures: fixedIngs })
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

  const user = result[0];
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

// Save a meal plan
app.post("/meal-plans", async (req, res) => {
  const { user_id, name, plan, recipe_ids } = req.body;
  if (!user_id || !plan) {
    res.status(400).json({ error: "user_id and plan required" });
    return;
  }

  const result = await db
    .insert(mealPlans)
    .values({ userId: user_id, name: name || "Yemek Planı", plan, recipeIds: recipe_ids ?? [] })
    .returning();

  res.status(201).json(toSnake(result[0]));
});

// Get user's meal plans
app.get("/users/:userId/meal-plans", async (req, res) => {
  const result = await db
    .select()
    .from(mealPlans)
    .where(eq(mealPlans.userId, req.params.userId))
    .orderBy(desc(mealPlans.createdAt));

  res.json(toSnake(result));
});

// Update a meal plan
app.put("/meal-plans/:id", async (req, res) => {
  const { name, plan, recipe_ids } = req.body;
  const updates: Record<string, any> = {};
  if (name) updates.name = name;
  if (plan) updates.plan = plan;
  if (recipe_ids) updates.recipeIds = recipe_ids;

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
});

// Delete a meal plan
app.delete("/meal-plans/:id", async (req, res) => {
  await db.delete(mealPlans).where(eq(mealPlans.id, req.params.id));
  res.status(204).send();
});

// List all predefined tags
app.get("/tags", async (_req, res) => {
  const result = await db.select().from(tags).orderBy(tags.name);
  res.json(result.map((r) => r.name));
});

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

        availableRecipes = userRecipeRows.map((r) => ({
          title: r.title,
          tags: r.tags as string[],
          cooking_time_minutes: r.cookingTimeMinutes ?? 30,
          cuisine: r.cuisine,
          ingredients: (r.ingredientsWithoutMeasures as string[]) || [],
        }));
      }
    }

    const result = await generateMealPlan({
      ...req.body,
      available_recipes: availableRecipes,
    });
    res.json(result);
  } catch (err: any) {
    console.error("[AI MealPlan]", err.message || err);
    res.status(500).json({ error: "Meal plan generation failed" });
  }
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
