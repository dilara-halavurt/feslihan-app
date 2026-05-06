import { S3Client, PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";
import { randomUUID } from "crypto";

const BUCKET = "feslihan-images";
const REGION = "us-east-1";

const s3 = new S3Client({ region: REGION });

export async function uploadImage(
  base64Data: string,
  contentType = "image/jpeg"
): Promise<string> {
  const buffer = Buffer.from(base64Data, "base64");
  const key = `thumbnails/${randomUUID()}.jpg`;

  await s3.send(
    new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      Body: buffer,
      ContentType: contentType,
    })
  );

  return `https://${BUCKET}.s3.${REGION}.amazonaws.com/${key}`;
}

export function s3KeyFromUrl(rawUrl: string): string | null {
  const prefix = `https://${BUCKET}.s3.${REGION}.amazonaws.com/`;
  if (!rawUrl.startsWith(prefix)) return null;
  return rawUrl.slice(prefix.length);
}

export async function getImage(key: string): Promise<Buffer | null> {
  try {
    const res = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
    const bytes = await res.Body?.transformToByteArray();
    return bytes ? Buffer.from(bytes) : null;
  } catch {
    return null;
  }
}
