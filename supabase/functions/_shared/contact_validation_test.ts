import { validateContactInput } from './contact_validation.ts';

const valid = {
  name: ' Ana  Pérez ', email: ' ANA@example.com ',
  subject: 'Consulta general', message: 'Necesito información sobre mi cuenta.',
};

Deno.test('normalizes a valid anonymous or signed-in contact payload', () => {
  const value = validateContactInput(valid);
  if (value?.name !== 'Ana Pérez' || value.email !== 'ana@example.com') {
    throw new Error('contact payload normalization failed');
  }
});

Deno.test('rejects missing, invalid and oversized fields', () => {
  const invalid = [
    null,
    { ...valid, name: '' },
    { ...valid, email: 'invalid' },
    { ...valid, subject: 'Inventado' },
    { ...valid, message: 'corto' },
    { ...valid, message: 'x'.repeat(4001) },
    { ...valid, name: 4 },
    { ...valid, is_admin: true },
  ];
  for (const item of invalid) {
    if (validateContactInput(item) !== null) throw new Error('invalid payload accepted');
  }
});
