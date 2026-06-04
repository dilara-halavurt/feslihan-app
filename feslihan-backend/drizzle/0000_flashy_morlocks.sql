CREATE TYPE "public"."availability" AS ENUM('easy', 'neutral', 'rare');--> statement-breakpoint
CREATE TYPE "public"."difficulty_type" AS ENUM('low', 'medium', 'high');--> statement-breakpoint
CREATE TYPE "public"."platform_type" AS ENUM('instagram', 'tiktok', 'x', 'other');--> statement-breakpoint
CREATE TYPE "public"."price_tier" AS ENUM('cheap', 'neutral', 'expensive');--> statement-breakpoint
CREATE TYPE "public"."subscription_plan" AS ENUM('free', 'plus', 'pro');--> statement-breakpoint
CREATE TABLE "ingredients" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" varchar(255) NOT NULL,
	"price_tier" "price_tier",
	"availability" "availability",
	"price_per_unit" real,
	"price_unit" varchar(20),
	"price_updated_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ingredients_name_unique" UNIQUE("name")
);
--> statement-breakpoint
CREATE TABLE "meal_plans" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" varchar(255) NOT NULL,
	"name" varchar(255) NOT NULL,
	"plan" jsonb NOT NULL,
	"recipe_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "platform_creators" (
	"username" varchar(255) PRIMARY KEY NOT NULL,
	"platform" "platform_type" NOT NULL,
	"display_name" varchar(255),
	"profile_picture_url" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "recipes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"platform" "platform_type" NOT NULL,
	"platform_user" varchar(255) NOT NULL,
	"url" text NOT NULL,
	"likes_count" integer DEFAULT 0 NOT NULL,
	"comments_count" integer DEFAULT 0 NOT NULL,
	"caption" text,
	"title" varchar(500) NOT NULL,
	"description" text NOT NULL,
	"ingredients_with_measures" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"ingredients_without_measures" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"thumbnail_url" text,
	"servings" integer,
	"calories_total_kcal" real,
	"calories_total_joules" real,
	"calories_per_serving_kcal" real,
	"protein_grams" real,
	"carbs_grams" real,
	"fat_grams" real,
	"fiber_grams" real,
	"tags" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"cooking_time_minutes" integer NOT NULL,
	"cuisine" varchar(50),
	"difficulty" "difficulty_type",
	"freezer_friendly" boolean DEFAULT false NOT NULL,
	"health_score" real,
	"requested_by" varchar(255) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "recipes_url_unique" UNIQUE("url")
);
--> statement-breakpoint
CREATE TABLE "tags" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" varchar(100) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "tags_name_unique" UNIQUE("name")
);
--> statement-breakpoint
CREATE TABLE "user_folders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" varchar(255) NOT NULL,
	"name" varchar(255) NOT NULL,
	"emoji" varchar(10),
	"sort_order" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_pantry" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" varchar(255) NOT NULL,
	"ingredient_id" uuid NOT NULL,
	"added_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_recipes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" varchar(255) NOT NULL,
	"recipe_id" uuid NOT NULL,
	"folder_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_shopping_list" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" varchar(255) NOT NULL,
	"ingredient_id" uuid NOT NULL,
	"is_checked" boolean DEFAULT false NOT NULL,
	"added_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"clerk_id" varchar(255) PRIMARY KEY NOT NULL,
	"email" varchar(255),
	"name" varchar(255),
	"avatar_url" text,
	"subscription_plan" "subscription_plan" DEFAULT 'free' NOT NULL,
	"recipes_used_this_month" integer DEFAULT 0 NOT NULL,
	"usage_reset_month" varchar(7),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "meal_plans" ADD CONSTRAINT "meal_plans_user_id_users_clerk_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("clerk_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "recipes" ADD CONSTRAINT "recipes_platform_user_platform_creators_username_fk" FOREIGN KEY ("platform_user") REFERENCES "public"."platform_creators"("username") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_folders" ADD CONSTRAINT "user_folders_user_id_users_clerk_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("clerk_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_pantry" ADD CONSTRAINT "user_pantry_user_id_users_clerk_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("clerk_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_pantry" ADD CONSTRAINT "user_pantry_ingredient_id_ingredients_id_fk" FOREIGN KEY ("ingredient_id") REFERENCES "public"."ingredients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_recipes" ADD CONSTRAINT "user_recipes_user_id_users_clerk_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("clerk_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_recipes" ADD CONSTRAINT "user_recipes_recipe_id_recipes_id_fk" FOREIGN KEY ("recipe_id") REFERENCES "public"."recipes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_recipes" ADD CONSTRAINT "user_recipes_folder_id_user_folders_id_fk" FOREIGN KEY ("folder_id") REFERENCES "public"."user_folders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_shopping_list" ADD CONSTRAINT "user_shopping_list_user_id_users_clerk_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("clerk_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_shopping_list" ADD CONSTRAINT "user_shopping_list_ingredient_id_ingredients_id_fk" FOREIGN KEY ("ingredient_id") REFERENCES "public"."ingredients"("id") ON DELETE no action ON UPDATE no action;