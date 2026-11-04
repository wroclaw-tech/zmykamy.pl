import { and, asc, eq, isNull, or } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { packingItem } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { getFirstRow } from "../lib/db-rows";
import { ApiError } from "../lib/errors";
import { assertValidAssignee } from "../lib/assignee";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";
import {
  createPackingItemSchema,
  packingItemParamSchema,
  updatePackingItemSchema,
} from "../schemas/packing";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

const isVisibleTo = (userId: string) =>
  or(isNull(packingItem.ownerId), eq(packingItem.ownerId, userId));

const toPackingItemResponse = (item: typeof packingItem.$inferSelect) => ({
  id: item.id,
  scope: item.ownerId ? "personal" : "shared",
  name: item.name,
  assigneeId: item.assigneeId,
  isPacked: item.isPacked,
  createdBy: item.createdBy,
  createdAt: item.createdAt,
});

const getVisibleItem = async (tripId: string, itemId: string, userId: string) => {
  const item = await db.query.packingItem.findFirst({
    where: and(eq(packingItem.id, itemId), eq(packingItem.tripId, tripId), isVisibleTo(userId)),
  });
  if (!item) {
    throw new ApiError(404, "packing_item_not_found", "Packing item not found");
  }
  return item;
};

export const packing = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/packing", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    const userId = c.get("user").id;
    await getMemberTrip(id, userId);
    const items = await db.query.packingItem.findMany({
      where: and(eq(packingItem.tripId, id), isVisibleTo(userId)),
      orderBy: [asc(packingItem.createdAt)],
    });
    return c.json(items.map(toPackingItemResponse));
  })
  .post(
    "/:id/packing",
    validate("param", tripIdParamSchema),
    validate("json", createPackingItemSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      const record = await getMemberTrip(id, userId);
      const { scope, ...fields } = c.req.valid("json");
      assertValidAssignee(record.members, fields.assigneeId);
      const created = getFirstRow(
        await db
          .insert(packingItem)
          .values({
            ...fields,
            tripId: id,
            ownerId: scope === "personal" ? userId : null,
            createdBy: userId,
          })
          .returning({ id: packingItem.id }),
      );
      return c.json(toPackingItemResponse(await getVisibleItem(id, created.id, userId)), 201);
    },
  )
  .patch(
    "/:id/packing/:itemId",
    validate("param", packingItemParamSchema),
    validate("json", updatePackingItemSchema),
    async (c) => {
      const { id, itemId } = c.req.valid("param");
      const userId = c.get("user").id;
      const record = await getMemberTrip(id, userId);
      const item = await getVisibleItem(id, itemId, userId);
      const fields = c.req.valid("json");
      if (fields.assigneeId !== undefined) {
        if (item.ownerId && fields.assigneeId !== null) {
          throw new ApiError(
            400,
            "personal_item_unassignable",
            "Personal items cannot be assigned",
          );
        }
        assertValidAssignee(record.members, fields.assigneeId);
      }
      await db.update(packingItem).set(fields).where(eq(packingItem.id, itemId));
      return c.json(toPackingItemResponse(await getVisibleItem(id, itemId, userId)));
    },
  )
  .delete("/:id/packing/:itemId", validate("param", packingItemParamSchema), async (c) => {
    const { id, itemId } = c.req.valid("param");
    const userId = c.get("user").id;
    await getMemberTrip(id, userId);
    await getVisibleItem(id, itemId, userId);
    await db.delete(packingItem).where(eq(packingItem.id, itemId));
    return c.body(null, 204);
  });
