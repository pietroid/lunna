// How big a client spreadsheet and a WhatsApp inbox are once written out for
// the model, against what the agent takes today. Synthetic, deterministic.
// Tokens are estimated at 4 characters each, as data/schema-size.txt of the
// agent-full-surface RFC did. Run: node code/sizes.mjs > data/sizes.csv
const CAP = 4000; // agent.controller.ts:187, a message is cut here

const names = ['Ana Souza', 'Bruno Lima', 'Carla Dias', 'Diego Rocha', 'Elisa Prado', 'Fábio Nunes', 'Gabi Torres', 'Hugo Melo'];
const services = ['Identidade visual', 'Posts do mês', 'Cardápio', 'Site institucional', 'Convite de casamento', 'Catálogo'];
const status = ['Briefing', 'Em produção', 'Aguardando cliente', 'Aprovado'];

function rows(n) {
  return Array.from({ length: n }, (_, i) => ({
    Cliente: `${names[i % names.length]} ${Math.floor(i / names.length) + 1}`,
    Serviço: services[(i * 7) % services.length],
    Prazo: `2026-${String(11 + (i % 2)).padStart(2, '0')}-${String(1 + ((i * 3) % 28)).padStart(2, '0')}`,
    Valor: `R$ ${(800 + ((i * 137) % 40) * 50).toLocaleString('pt-BR')}`,
    Status: status[i % status.length],
    Observações: i % 3 === 0 ? 'Pediu duas versões do logo, enviar até sexta' : '',
  }));
}
const csv = (r) => [Object.keys(r[0]).join(','), ...r.map((o) => Object.values(o).map((v) => (v.includes(',') ? `"${v}"` : v)).join(','))].join('\n');
const kv = (r) => r.map((o, i) => `## Linha ${i + 2}\n` + Object.entries(o).filter(([, v]) => v !== '').map(([k, v]) => `${k}: ${v}`).join('\n')).join('\n\n');

const lines = ['what,count,csv_chars,csv_tokens,kv_chars,kv_tokens,fits_one_message'];
for (const n of [10, 30, 100, 300]) {
  const r = rows(n), c = csv(r), k = kv(r);
  lines.push(`sheet rows,${n},${c.length},${Math.round(c.length / 4)},${k.length},${Math.round(k.length / 4)},${c.length <= CAP ? 'yes' : 'no'}`);
}
// An inbox: each chat as its contact, then its last messages, newest last.
const msg = ['Oi! Tudo bem? Consegue me mandar o orçamento?', 'Vi a prévia, amei! Só muda a cor do fundo', 'Qual o prazo pra entrega?', 'Pode ser amanhã às 15h?', 'Paguei o sinal, segue o comprovante'];
for (const [chats, per] of [[10, 5], [30, 10], [80, 10]]) {
  let s = '';
  for (let c = 0; c < chats; c++) {
    s += `### ${names[c % names.length]} (+55 11 9${String(1000 + c).padStart(4, '0')}-${String(c * 37).padStart(4, '0')})\n`;
    for (let m = 0; m < per; m++) s += `[27/10 ${String(9 + (m % 9)).padStart(2, '0')}:${String((m * 7) % 60).padStart(2, '0')}] ${m % 2 ? 'Eu' : 'Cliente'}: ${msg[(c + m) % msg.length]}\n`;
  }
  lines.push(`inbox chats x${per} msgs,${chats},${s.length},${Math.round(s.length / 4)},,,${s.length <= CAP ? 'yes' : 'no'}`);
}
console.log(lines.join('\n'));
