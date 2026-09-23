import type { Request, Response, NextFunction } from "express";
import { verifyToken } from "@clerk/backend";

// Augment Express Request with the authenticated user id derived from the Clerk JWT.
// The user id is ALWAYS taken from the verified token, never from path/body/query input.
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      auth?: { userId: string };
    }
  }
}

// Paths served without authentication (e.g. images loaded by AsyncImage/<img>,
// which cannot attach an Authorization header).
function isPublicPath(path: string): boolean {
  return path.startsWith("/images/");
}

// Verifies the Clerk session JWT on the Authorization header and attaches the
// resulting user id to req.auth. Rejects any request without a valid token.
export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  if (isPublicPath(req.path)) {
    next();
    return;
  }

  const secretKey = process.env.CLERK_SECRET_KEY;
  if (!secretKey) {
    console.error("[auth] CLERK_SECRET_KEY is not configured");
    res.status(500).json({ error: "Server auth not configured" });
    return;
  }

  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing bearer token" });
    return;
  }
  const token = header.slice("Bearer ".length).trim();

  const { data, errors } = await verifyToken(token, { secretKey });
  if (errors || !data?.sub) {
    console.error(
      "[auth] Token verification failed:",
      errors?.[0]?.message ?? "no subject"
    );
    res.status(401).json({ error: "Invalid or expired token" });
    return;
  }

  req.auth = { userId: data.sub };
  next();
}
