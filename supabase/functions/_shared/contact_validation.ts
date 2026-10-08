export type ContactInput = {
  name: string;
  email: string;
  subject: string;
  message: string;
};

const subjects = new Set([
  'Consulta general', 'Problema con mi cuenta', 'Negocio o publicación',
  'Privacidad y datos', 'Otro',
]);

export function validateContactInput(value: unknown): ContactInput | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const input = value as Record<string, unknown>;
  if (Object.keys(input).some((key) =>
      !['name', 'email', 'subject', 'message'].includes(key))) return null;
  if (typeof input.name !== 'string' || typeof input.email !== 'string' ||
      typeof input.subject !== 'string' || typeof input.message !== 'string') {
    return null;
  }
  const name = input.name.trim().replace(/\s+/g, ' ');
  const email = input.email.trim().toLowerCase();
  const subject = input.subject.trim();
  const message = input.message.trim().replace(/\r\n/g, '\n');
  if (name.length < 3 || name.length > 120 ||
      email.length < 5 || email.length > 254 ||
      !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
      !subjects.has(subject) ||
      message.length < 10 || message.length > 4000) {
    return null;
  }
  return { name, email, subject, message };
}
