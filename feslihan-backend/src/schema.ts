import {
  pgTable,
  uuid,
  varchar,
  text,
  integer,
  real,
  jsonb,
  timestamp,
  pgEnum,
} from "drizzle-orm/pg-core";

export const subscriptionPlanEnum = pgEnum("subscription_plan", [
  "free",
  "plus",
  "pro",
]);

export const users = pgTable("users", {
  clerkId: varchar("clerk_id", { length: 255 }).primaryKey(),
  email: varchar("email", { length: 255 }),
  name: varchar("name", { length: 255 }),
  avatarUrl: text("avatar_url"),
  subscriptionPlan: subscriptionPlanEnum("subscription_plan").notNull().default("free"),
  recipesUsedThisMonth: integer("recipes_used_this_month").notNull().default(0),
  usageResetMonth: varchar("usage_reset_month", { length: 7 }),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;

export const platformEnum = pgEnum("platform_type", [
  "instagram",
  "tiktok",
  "x",
  "other",
]);

export const difficultyEnum = pgEnum("difficulty_type", [
  "low",
  "medium",
  "high",
]);

export const platformCreators = pgTable("platform_creators", {
  username: varchar("username", { length: 255 }).primaryKey(),
  platform: platformEnum("platform").notNull(),
  displayName: varchar("display_name", { length: 255 }),
  profilePictureUrl: text("profile_picture_url"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
  createdBy: varchar("created_by", { length: 255 }),
});

export const recipes = pgTable("recipes", {
  id: uuid("id").primaryKey().defaultRandom(),

  // Source info
  platform: platformEnum("platform").notNull(),
  platformUser: varchar("platform_user", { length: 255 }).notNull().references(() => platformCreators.username),
  url: text("url").notNull().unique(),
  likesCount: integer("likes_count").notNull().default(0),
  commentsCount: integer("comments_count").notNull().default(0),
  caption: text("caption"),

  // Recipe content
  title: varchar("title", { length: 500 }).notNull(),
  description: text("description").notNull(),
  ingredientsWithMeasures: jsonb("ingredients_with_measures")
    .notNull()
    .default([]),
  ingredientsWithoutMeasures: jsonb("ingredients_without_measures")
    .notNull()
    .default([]),
  thumbnailUrl: text("thumbnail_url"),
  servings: integer("servings"),

  // Nutrition
  caloriesTotalKcal: real("calories_total_kcal"),
  caloriesTotalJoules: real("calories_total_joules"),
  caloriesPerServingKcal: real("calories_per_serving_kcal"),
  proteinGrams: real("protein_grams"),
  carbsGrams: real("carbs_grams"),
  fatGrams: real("fat_grams"),
  fiberGrams: real("fiber_grams"),

  // Classification
  tags: jsonb("tags").notNull().default([]),
  cookingTimeMinutes: integer("cooking_time_minutes").notNull(),
  cuisine: varchar("cuisine", { length: 50 }),
  difficulty: difficultyEnum("difficulty"),
  healthScore: real("health_score"),

  // Tracking
  requestedBy: varchar("requested_by", { length: 255 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const ingredients = pgTable("ingredients", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: varchar("name", { length: 255 }).notNull().unique(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
  createdBy: varchar("created_by", { length: 255 }),
});

export const tags = pgTable("tags", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: varchar("name", { length: 100 }).notNull().unique(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
  createdBy: varchar("created_by", { length: 255 }),
});

export const userFolders = pgTable("user_folders", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  name: varchar("name", { length: 255 }).notNull(),
  emoji: varchar("emoji", { length: 10 }),
  sortOrder: integer("sort_order").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const userRecipes = pgTable("user_recipes", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  recipeId: uuid("recipe_id")
    .notNull()
    .references(() => recipes.id),
  folderId: uuid("folder_id")
    .references(() => userFolders.id),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const mealPlans = pgTable("meal_plans", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  name: varchar("name", { length: 255 }).notNull(),
  plan: jsonb("plan").notNull(),
  recipeIds: jsonb("recipe_ids").notNull().default([]),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export type Recipe = typeof recipes.$inferSelect;
export type NewRecipe = typeof recipes.$inferInsert;
export type IngredientRow = typeof ingredients.$inferSelect;
export type TagRow = typeof tags.$inferSelect;
export type PlatformCreator = typeof platformCreators.$inferSelect;
