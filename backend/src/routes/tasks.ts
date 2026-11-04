import { and, asc, eq, sql } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { tripTask } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { getFirstRow } from "../lib/db-rows";
import { ApiError } from "../lib/errors";
import { assertValidAssignee } from "../lib/assignee";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";
import { createTaskSchema, taskParamSchema, updateTaskSchema } from "../schemas/task";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

type Task = typeof tripTask.$inferSelect;

const toTaskResponse = (task: Task) => ({
  id: task.id,
  title: task.title,
  assigneeId: task.assigneeId,
  dueDate: task.dueDate,
  isDone: task.completedAt !== null,
  completedAt: task.completedAt,
  createdBy: task.createdBy,
  createdAt: task.createdAt,
});

const getTask = async (tripId: string, taskId: string) => {
  const task = await db.query.tripTask.findFirst({
    where: and(eq(tripTask.id, taskId), eq(tripTask.tripId, tripId)),
  });
  if (!task) {
    throw new ApiError(404, "task_not_found", "Task not found");
  }
  return task;
};

const getCompletedAt = (task: Task, isDone: boolean) =>
  isDone ? (task.completedAt ?? new Date()) : null;

export const tasks = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/tasks", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    await getMemberTrip(id, c.get("user").id);
    const records = await db.query.tripTask.findMany({
      where: eq(tripTask.tripId, id),
      orderBy: [sql`${tripTask.dueDate} ASC NULLS LAST`, asc(tripTask.createdAt)],
    });
    return c.json(records.map(toTaskResponse));
  })
  .post(
    "/:id/tasks",
    validate("param", tripIdParamSchema),
    validate("json", createTaskSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      const record = await getMemberTrip(id, userId);
      const fields = c.req.valid("json");
      assertValidAssignee(record.members, fields.assigneeId);
      const created = getFirstRow(
        await db
          .insert(tripTask)
          .values({ ...fields, tripId: id, createdBy: userId })
          .returning({ id: tripTask.id }),
      );
      return c.json(toTaskResponse(await getTask(id, created.id)), 201);
    },
  )
  .patch(
    "/:id/tasks/:taskId",
    validate("param", taskParamSchema),
    validate("json", updateTaskSchema),
    async (c) => {
      const { id, taskId } = c.req.valid("param");
      const record = await getMemberTrip(id, c.get("user").id);
      const task = await getTask(id, taskId);
      const { isDone, ...fields } = c.req.valid("json");
      if (fields.assigneeId !== undefined) {
        assertValidAssignee(record.members, fields.assigneeId);
      }
      await db
        .update(tripTask)
        .set({
          ...fields,
          ...(isDone !== undefined ? { completedAt: getCompletedAt(task, isDone) } : {}),
        })
        .where(eq(tripTask.id, taskId));
      return c.json(toTaskResponse(await getTask(id, taskId)));
    },
  )
  .delete("/:id/tasks/:taskId", validate("param", taskParamSchema), async (c) => {
    const { id, taskId } = c.req.valid("param");
    await getMemberTrip(id, c.get("user").id);
    await getTask(id, taskId);
    await db.delete(tripTask).where(eq(tripTask.id, taskId));
    return c.body(null, 204);
  });
