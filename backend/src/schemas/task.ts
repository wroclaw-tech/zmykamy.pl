import { z } from "zod";

const titleSchema = z.string().trim().min(1).max(120);
const assigneeIdSchema = z.string().min(1).nullable();
const dueDateSchema = z.iso.date().nullable();

export const taskParamSchema = z.object({ id: z.uuid(), taskId: z.uuid() });

export const createTaskSchema = z.object({
  title: titleSchema,
  assigneeId: assigneeIdSchema.default(null),
  dueDate: dueDateSchema.default(null),
});

export const updateTaskSchema = z
  .object({
    title: titleSchema,
    assigneeId: assigneeIdSchema,
    dueDate: dueDateSchema,
    isDone: z.boolean(),
  })
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required");
