import { and, asc, eq } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { planPoint, tripInfo } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { ApiError } from "../lib/errors";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";
import {
  createPlanPointSchema,
  createTripInfoSchema,
  planPointParamSchema,
  tripInfoParamSchema,
  updatePlanPointSchema,
  updateTripInfoSchema,
} from "../schemas/plan";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

type Author = { id: string; name: string } | null;

const toAuthorResponse = (author: Author) =>
  author ? { userId: author.id, name: author.name } : null;

const toPointResponse = (point: typeof planPoint.$inferSelect & { author: Author }) => ({
  id: point.id,
  date: point.date,
  time: point.time.slice(0, 5),
  title: point.title,
  description: point.description,
  place: point.place,
  latitude: point.latitude,
  longitude: point.longitude,
  icon: point.icon,
  author: toAuthorResponse(point.author),
});

const toInfoResponse = (info: typeof tripInfo.$inferSelect & { author: Author }) => ({
  id: info.id,
  title: info.title,
  text: info.text,
  icon: info.icon,
  author: toAuthorResponse(info.author),
});

const findPoint = (id: string, tripId: string) =>
  db.query.planPoint.findFirst({
    where: and(eq(planPoint.id, id), eq(planPoint.tripId, tripId)),
    with: { author: true },
  });

const findInfo = (id: string, tripId: string) =>
  db.query.tripInfo.findFirst({
    where: and(eq(tripInfo.id, id), eq(tripInfo.tripId, tripId)),
    with: { author: true },
  });

type MemberTrip = Awaited<ReturnType<typeof getMemberTrip>>;

const assertCanEdit = (record: MemberTrip, userId: string, createdBy: string | null) => {
  const role = record.members.find((member) => member.userId === userId)?.role;
  if (role !== "organizer" && createdBy !== userId) {
    throw new ApiError(403, "forbidden", "Only the author or an organizer can change this");
  }
};

const assertDateInTrip = (record: MemberTrip, date: string) => {
  if (date < record.startDate || date > record.endDate) {
    throw new ApiError(400, "date_out_of_range", "Date must be within the trip dates");
  }
};

const notFound = (code: string, message: string) => new ApiError(404, code, message);

export const plan = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/plan", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    await getMemberTrip(id, c.get("user").id);
    const [points, info] = await Promise.all([
      db.query.planPoint.findMany({
        where: eq(planPoint.tripId, id),
        with: { author: true },
        orderBy: [asc(planPoint.date), asc(planPoint.time), asc(planPoint.createdAt)],
      }),
      db.query.tripInfo.findMany({
        where: eq(tripInfo.tripId, id),
        with: { author: true },
        orderBy: [asc(tripInfo.createdAt)],
      }),
    ]);
    return c.json({ points: points.map(toPointResponse), info: info.map(toInfoResponse) });
  })
  .post(
    "/:id/plan/points",
    validate("param", tripIdParamSchema),
    validate("json", createPlanPointSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      const body = c.req.valid("json");
      assertDateInTrip(await getMemberTrip(id, userId), body.date);
      const [created] = await db
        .insert(planPoint)
        .values({ ...body, tripId: id, createdBy: userId })
        .returning({ id: planPoint.id });
      return c.json(toPointResponse((await findPoint(created!.id, id))!), 201);
    },
  )
  .patch(
    "/:id/plan/points/:pointId",
    validate("param", planPointParamSchema),
    validate("json", updatePlanPointSchema),
    async (c) => {
      const { id, pointId } = c.req.valid("param");
      const userId = c.get("user").id;
      const body = c.req.valid("json");
      const record = await getMemberTrip(id, userId);
      const current = await findPoint(pointId, id);
      if (!current) {
        throw notFound("point_not_found", "Plan point not found");
      }
      assertCanEdit(record, userId, current.createdBy);
      if (body.date) {
        assertDateInTrip(record, body.date);
      }
      await db.update(planPoint).set(body).where(eq(planPoint.id, pointId));
      return c.json(toPointResponse((await findPoint(pointId, id))!));
    },
  )
  .delete("/:id/plan/points/:pointId", validate("param", planPointParamSchema), async (c) => {
    const { id, pointId } = c.req.valid("param");
    const userId = c.get("user").id;
    const record = await getMemberTrip(id, userId);
    const current = await findPoint(pointId, id);
    if (!current) {
      throw notFound("point_not_found", "Plan point not found");
    }
    assertCanEdit(record, userId, current.createdBy);
    await db.delete(planPoint).where(eq(planPoint.id, pointId));
    return c.body(null, 204);
  })
  .post(
    "/:id/plan/info",
    validate("param", tripIdParamSchema),
    validate("json", createTripInfoSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      await getMemberTrip(id, userId);
      const [created] = await db
        .insert(tripInfo)
        .values({ ...c.req.valid("json"), tripId: id, createdBy: userId })
        .returning({ id: tripInfo.id });
      return c.json(toInfoResponse((await findInfo(created!.id, id))!), 201);
    },
  )
  .patch(
    "/:id/plan/info/:infoId",
    validate("param", tripInfoParamSchema),
    validate("json", updateTripInfoSchema),
    async (c) => {
      const { id, infoId } = c.req.valid("param");
      const userId = c.get("user").id;
      const record = await getMemberTrip(id, userId);
      const current = await findInfo(infoId, id);
      if (!current) {
        throw notFound("info_not_found", "Trip info not found");
      }
      assertCanEdit(record, userId, current.createdBy);
      await db.update(tripInfo).set(c.req.valid("json")).where(eq(tripInfo.id, infoId));
      return c.json(toInfoResponse((await findInfo(infoId, id))!));
    },
  )
  .delete("/:id/plan/info/:infoId", validate("param", tripInfoParamSchema), async (c) => {
    const { id, infoId } = c.req.valid("param");
    const userId = c.get("user").id;
    const record = await getMemberTrip(id, userId);
    const current = await findInfo(infoId, id);
    if (!current) {
      throw notFound("info_not_found", "Trip info not found");
    }
    assertCanEdit(record, userId, current.createdBy);
    await db.delete(tripInfo).where(eq(tripInfo.id, infoId));
    return c.body(null, 204);
  });
