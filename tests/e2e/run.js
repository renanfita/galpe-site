/* E2E de navegador (Playwright + Chromium) com Supabase mockado.
   Uso: ver tests/README.md. Não roda em CI da Vercel — verificação de dev.
   Sem o pacote `playwright` instalado, cai para playwright-core + Edge do sistema.
   GALPE_E2E_CHROME=/caminho/chromium usa um binário próprio (sandboxes sem
   acesso ao CDN do Playwright: npm i --no-save @sparticuz/chromium). */
let chromium, usaCore = false;
try { ({ chromium } = require('playwright')); }
catch (e) { ({ chromium } = require('playwright-core')); usaCore = true; }
const fs = require('fs');
const http = require('http');
const path = require('path');

const SITE = path.resolve(__dirname, '..', '..');
const MOCK_LIB = fs.readFileSync(path.join(__dirname, 'mock-supabase.js'), 'utf8');
const PORT = 8777;
const BASE = 'http://localhost:' + PORT;

let passed = 0, failed = 0;
function ok(cond, msg){
  if(cond){ passed++; console.log('  OK  ' + msg); }
  else { failed++; console.log('  FALHA ' + msg); }
}

const MIME = { '.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.xml':'text/xml', '.txt':'text/plain', '.webp':'image/webp', '.jpg':'image/jpeg' };
const server = http.createServer((req, res) => {
  const p = path.join(SITE, decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, '/index.html'));
  fs.readFile(p, (err, data) => {
    if(err){ res.writeHead(404); res.end('404'); return; }
    // SRI: o mock do CDN nunca bate o hash real — remover integrity no HTML servido ao teste
    if(path.extname(p) === '.html') data = Buffer.from(data.toString().replace(/ integrity="[^"]*"/g, ''));
    res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' });
    res.end(data);
  });
});

const SEED_CONFIG = [
  ['whatsapp','5521995060184'],['telefone_exibicao','(21) 99506-0184'],['email','festanogalpe@gmail.com'],
  ['instagram','@festanogalpe'],['endereco','Rua Yeda, 184 – Tijuca, Teresópolis/RJ'],['duracao_horas',4],
  ['sinal_percent',10],['validade_proposta_dias',7],['hora_extra_antecipada_percent',15],['hora_extra_dia_percent',20],
  ['criancas_gratis_ate',5],['meia_de',6],['meia_ate',9],['docinhos_por_pessoa',5],['tolerancia_min',30],
  ['max_extra_percent',10],['comida_verdade_preco',25],['meta_festas_mes',8],['meta_receita_mes',80000],
  ['ga4_id','G-TEST123'],['razao_social','Galpê Buffet Ltda.'],['cnpj','12.345.678/0001-90'],['pix_chave','pix@galpe.com.br']
].map(([key, value]) => ({ key, value }));

const SEED_PRECOS = [];
[['seg',[134,129,119,114]],['sex',[142,137,127,122]],['sab',[149,144,134,129]]].forEach(([dia, vals]) => {
  [60,80,100,150].forEach((c, i) => SEED_PRECOS.push({ dia, convidados: c, valor: vals[i] }));
});

function adminSeed(extra){
  return Object.assign({
    site_config: JSON.parse(JSON.stringify(SEED_CONFIG)),
    precos: JSON.parse(JSON.stringify(SEED_PRECOS)),
    upgrades: [{ id: 'u1', nome: 'Comida de verdade', descricao: '', preco: 25, unidade: 'por_pessoa', ativo: true, ordem: 1 },
               { id: 'u2', nome: 'Drinks', descricao: '', preco: 300, unidade: 'fixo', ativo: true, ordem: 2 }],
    leads: [{ id: 'l1', nome: 'Maria da Silva', telefone: '(21) 98888-7777', origem: 'site', status: 'novo', created_at: new Date().toISOString() }],
    propostas: [], eventos: [], bloqueios: [], contratos: []
  }, extra || {});
}

async function newPage(browser, db, rpcJs){
  const ctx = await browser.newContext({ permissions: ['clipboard-read', 'clipboard-write'] });
  await ctx.addInitScript({ content:
    'window.__MOCK_DB = ' + JSON.stringify(db) + ';\n' +
    'window.__MOCK_RPC = ' + (rpcJs || '{}') + ';\n' +
    'window.print = function(){ window.__PRINTED = true; };'
  });
  // CDN do supabase → mock; resto de terceiros → aborta (offline real)
  await ctx.route('**/*', (route) => {
    const url = route.request().url();
    if(url.includes('dist/umd/supabase.')) return route.fulfill({ contentType: 'text/javascript', body: MOCK_LIB });
    if(url.startsWith(BASE) || url.startsWith('data:')) return route.continue();
    if(url.includes('atzcjyweglcyrztwpisv.supabase.co')){
      // REST usada pelo index.html via fetch()
      if(url.includes('/rest/v1/precos')) return route.fulfill({ json: SEED_PRECOS });
      if(url.includes('/rest/v1/upgrades')) return route.fulfill({ json: [{ nome: 'Comida de verdade', preco: 30, unidade: 'por_pessoa' }, { nome: 'Drinks', preco: 300, unidade: 'fixo' }] });
      if(url.includes('/rest/v1/site_config')) return route.fulfill({ json: [{ key: 'comida_verdade_preco', value: 30 }, { key: 'ga4_id', value: 'G-TEST123' }] });
      if(url.includes('/rest/v1/leads')){ leadPosts.push(route.request().postData()); return route.fulfill({ status: 201, body: '' }); }
      return route.fulfill({ json: [] });
    }
    if(url.includes('googletagmanager.com')){ gtagRequests.push(url); return route.fulfill({ contentType: 'text/javascript', body: '/* gtag mock */' }); }
    return route.abort();
  });
  const page = await ctx.newPage();
  page.on('pageerror', e => { pageErrors.push(page.url() + ' :: ' + e.message); });
  return { ctx, page };
}

let pageErrors = [], gtagRequests = [], leadPosts = [];

(async () => {
  server.listen(PORT);
  const browser = await chromium.launch(
    process.env.GALPE_E2E_CHROME
      ? { executablePath: process.env.GALPE_E2E_CHROME, args: ['--no-sandbox', '--disable-dev-shm-usage'] }
      : usaCore ? { channel: 'msedge' } : {});

  /* ================= ADMIN ================= */
  console.log('\n== admin.html: login → dashboard → proposta → contrato → métricas ==');
  {
    const { ctx, page } = await newPage(browser, adminSeed());
    await page.goto(BASE + '/admin.html');
    await page.fill('#loginEmail', 'admin@galpe.test');
    await page.fill('#loginPass', 'senha-forte');
    await page.click('#loginBtn');
    await page.waitForSelector('#app', { state: 'visible' });
    ok(true, 'login entra no app');
    await page.waitForFunction(() => document.getElementById('kpiFestas').textContent !== '–');
    ok(await page.textContent('#kpiFestas') === '0', 'KPI festas do mês = 0');
    const metas = await page.textContent('#dashMetas');
    ok(metas.includes('Festas fechadas') && metas.includes('Receita prevista') && metas.includes('80.000'), 'painel de metas com barras (8 festas / R$ 80.000)');

    // nova proposta
    await page.click('[data-view="prop"]');
    await page.click('text=+ Nova proposta');
    await page.fill('#pr_cliente', 'Maria da Silva');
    await page.fill('#pr_aniversariante', 'Lia');
    await page.fill('#pr_data', '2026-08-15');
    await page.fill('#pr_convidados', '73');
    await page.fill('#pr_meia', '4');
    await page.dispatchEvent('#pr_convidados', 'change');
    const valor = await page.inputValue('#pr_valor');
    ok(valor === '149', 'preço sugerido pela faixa (73 sáb → 149), veio ' + valor);
    const calc = await page.textContent('#pr_calc');
    ok(calc.includes('10.877,00') || calc.includes('10.877'), 'cálculo da proposta com meia-entrada (73×149 + 4×74,50)');
    await page.click('#prSave');
    await page.waitForSelector('#modalProp.open', { state: 'detached' }).catch(() => {});
    await page.waitForFunction(() => document.querySelector('#propTable table'));
    ok((await page.textContent('#propTable')).includes('Maria da Silva'), 'proposta salva aparece na tabela');

    // PDF da proposta (janela de impressão)
    const [popup] = await Promise.all([page.waitForEvent('popup'), page.click('button[title="Baixar PDF da proposta"]')]);
    await popup.waitForLoadState('domcontentloaded');
    const pdfHtml = await popup.content();
    ok(pdfHtml.includes('GALPÊ') && pdfHtml.includes('Proposta para Maria da Silva') && pdfHtml.includes('Total da festa'), 'PDF da proposta com marca + investimento');
    await popup.waitForFunction(() => window.__PRINTED === true, null, { timeout: 5000 }).catch(() => {});
    ok(await popup.evaluate(() => window.__PRINTED === true), 'janela de impressão chamou print()');
    await popup.close();

    // gerar contrato a partir da proposta
    await page.click('button[title="Gerar contrato"]');
    await page.waitForSelector('#modalContrato.open');
    ok((await page.inputValue('#ct_nome')) === 'Maria da Silva', 'contrato prefillado com cliente');
    ok((await page.inputValue('#ct_valor')) === '11175.00', 'valor total trazido da proposta (73×149 + 4×74,50 = 11.175)');
    ok((await page.inputValue('#ct_sinal')) === '1117.50', 'sinal 10% sugerido (1.117,50)');
    const texto = await page.inputValue('#ct_texto');
    ok(texto.includes('GAL-') && texto.includes('Galpê Buffet Ltda., CNPJ 12.345.678/0001-90') && texto.includes('PIX, chave: pix@galpe.com.br'), 'texto do contrato gerado com dados da empresa');
    ok(texto.includes('73 convidados pagantes e 4 crianças de 6 a 9 anos'), 'cláusula de convidados com meia-entrada');
    await page.fill('#ct_cpf', '529.982.247-25');
    await page.click('#ctSave');
    await page.waitForFunction(() => document.querySelector('#contrTable table'));
    const linha = await page.textContent('#contrTable');
    ok(linha.includes('GAL-') && linha.includes('Rascunho'), 'contrato salvo como rascunho na lista');

    // copiar link marca como enviado
    await page.click('button[title="Copiar link de assinatura"]');
    await page.waitForFunction(() => document.getElementById('contrTable').textContent.includes('Enviado'));
    ok(true, 'copiar link marca contrato como Enviado');
    const link = await page.evaluate(() => navigator.clipboard.readText());
    ok(/contrato\.html\?t=[0-9a-f-]{36}/.test(link), 'link copiado aponta para contrato.html?t=UUID');

    // métricas
    await page.click('[data-view="met"]');
    await page.waitForSelector('#view-met.active');
    ok((await page.textContent('#metLeads')) === '1', 'métricas: 1 lead no período');
    ok((await page.textContent('#metFunil')).includes('Novo'), 'funil renderizado');
    ok((await page.textContent('#metOrigem')).includes('site'), 'origem renderizada');
    ok((await page.locator('#metReceita .vbar').count()) === 6, 'receita: 6 barras mensais');

    // ajustes com novos campos
    await page.click('[data-view="cfg"]');
    ok((await page.inputValue('#cfg_ga4_id')) === 'G-TEST123', 'Ajustes carrega ga4_id');
    ok((await page.inputValue('#cfg_meta_festas_mes')) === '8', 'Ajustes carrega meta de festas');
    await ctx.close();
  }

  /* ================= CONTRATO (assinatura) ================= */
  console.log('\n== contrato.html: render + validações + assinatura no canvas ==');
  {
    const token = '7f0a1bcd-2222-4333-8444-555566667777';
    const contratoData = {
      numero: 'GAL-2026-001', contratante_nome: 'Maria da Silva', aniversariante: 'Lia', tema: 'Zootopia',
      data_evento: '2026-08-15', horario: '12:00', convidados: 73, convidados_meia: 4,
      valor_total: 10877, sinal_valor: 1087.7, status: 'enviado',
      texto_contrato: 'CONTRATO Nº GAL-2026-001\n\n1. OBJETO. Festa no Galpê em 15/08/2026.\n\nASSINATURA ELETRÔNICA. Aceite pelo link vale como assinatura.'
    };
    const rpc = `{
      get_contrato: function(){ return ${JSON.stringify(contratoData)}; },
      assinar_contrato: function(p){
        window.__ASSINOU = p;
        if(!p.p_assinatura || p.p_assinatura.indexOf('data:image/png;base64,') !== 0) return { ok: false, erro: 'assinatura' };
        return { ok: true, assinado_em: new Date().toISOString(), hash: 'abc123hash' };
      }
    }`;
    const { ctx, page } = await newPage(browser, {}, rpc);
    await page.goto(BASE + '/contrato.html?t=' + token);
    await page.waitForSelector('#conteudo', { state: 'visible' });
    ok((await page.textContent('#cNum')).includes('GAL-2026-001'), 'contrato renderiza número');
    ok((await page.textContent('#cTexto')).includes('OBJETO'), 'texto integral exibido');
    ok((await page.textContent('#cMeta')).includes('R$ 10.877,00'), 'valor total no resumo');

    // validações
    await page.fill('#aNome', 'Maria da Silva');
    await page.fill('#aCpf', '52998224724'); // dígito errado
    await page.click('#btnAssinar');
    ok((await page.textContent('#aErro')).includes('CPF'), 'CPF inválido bloqueado');
    await page.fill('#aCpf', '52998224725');
    await page.click('#btnAssinar');
    ok((await page.textContent('#aErro')).includes('assinatura'), 'exige desenho da assinatura');

    // desenha no canvas
    const box = await page.locator('#sigCanvas').boundingBox();
    await page.mouse.move(box.x + 30, box.y + 60);
    await page.mouse.down();
    await page.mouse.move(box.x + 160, box.y + 90, { steps: 12 });
    await page.mouse.move(box.x + 240, box.y + 50, { steps: 12 });
    await page.mouse.up();
    await page.click('#btnAssinar');
    ok((await page.textContent('#aErro')).includes('caixinha'), 'exige o aceite marcado');
    await page.check('#aAceite');
    const [waPopup] = await Promise.all([page.waitForEvent('popup').catch(() => null), page.click('#btnAssinar')]);
    await page.waitForSelector('.badge-ok', { state: 'visible' });
    const badge = await page.textContent('#badgeOk');
    ok(badge.includes('Contrato assinado'), 'badge de assinado aparece');
    ok(badge.includes('abc123hash'), 'hash de verificação exibido');
    const payload = await page.evaluate(() => window.__ASSINOU);
    ok(payload && payload.p_token === token && payload.p_nome === 'Maria da Silva', 'RPC recebeu token + nome');
    ok(/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(payload.p_assinatura), 'assinatura enviada como PNG base64 válido');
    ok(payload.p_assinatura.length > 1000, 'desenho não está vazio (' + payload.p_assinatura.length + ' chars)');
    if(waPopup) await waPopup.close();
    ok((await page.locator('#assinarBox').isHidden()), 'formulário some após assinar');
    await ctx.close();
  }

  /* ================= CONTRATO já assinado / cancelado ================= */
  {
    const rpc = `{ get_contrato: function(){ return { numero:'GAL-2026-002', contratante_nome:'João', data_evento:'2026-09-01',
      convidados:60, convidados_meia:0, valor_total:9000, sinal_valor:900, status:'assinado',
      assinado_em:'2026-06-12T12:00:00Z', assinante_nome:'João Souza', assinante_cpf_mask:'***.982.247-**',
      aceite_hash:'ff00', assinatura_img:'data:image/png;base64,iVBORw0KGgo=', texto_contrato:'CONTRATO...' }; } }`;
    const { ctx, page } = await newPage(browser, {}, rpc);
    await page.goto(BASE + '/contrato.html?t=7f0a1bcd-2222-4333-8444-555566667778');
    await page.waitForSelector('#conteudo', { state: 'visible' });
    ok((await page.textContent('#badgeOk')).includes('João Souza'), 'contrato já assinado mostra comprovante');
    ok(await page.locator('#assinarBox').isHidden(), 'sem formulário quando já assinado');
    await ctx.close();
  }

  /* ================= PROPOSTA pública ================= */
  console.log('\n== proposta.html: render + botão PDF ==');
  {
    const rpc = `{ get_proposta: function(){ return { nome_cliente:'Maria', aniversariante:'Lia', idade:5, tema:'Zootopia',
      data_evento:'2026-08-15', horario:'12:00', convidados:73, convidados_meia:4, dia_tipo:'sab', valor_pessoa:149,
      upgrades:[{nome:'Comida de verdade', unidade:'por_pessoa', preco:25},{nome:'Drinks', unidade:'fixo', preco:300}],
      desconto:50, observacoes:null, validade:'2026-07-01', status:'enviada' }; },
      aceitar_proposta: function(){ return true; } }`;
    const db = { site_config: JSON.parse(JSON.stringify(SEED_CONFIG)) };
    const { ctx, page } = await newPage(browser, db, rpc);
    await page.goto(BASE + '/proposta.html?t=7f0a1bcd-2222-4333-8444-555566667779');
    await page.waitForSelector('#conteudo', { state: 'visible' });
    const tab = await page.textContent('#pTabela');
    ok(tab.includes('R$ 13.350,00'), 'total da proposta confere (13.350 = 73×149 + 4×74,5 + 77×25 + 300 − 50)');
    ok(await page.locator('button.btn-print').isVisible(), 'botão "Salvar em PDF" presente');
    await page.click('button.btn-print');
    ok(await page.evaluate(() => window.__PRINTED === true), 'botão dispara impressão');
    await ctx.close();
  }

  /* ================= ADMIN: copiar link promove proposta ================= */
  console.log('\n== admin.html: copiar link promove rascunho → enviada ==');
  {
    const TK = '11111111-1111-4111-8111-111111111111';
    const propBase = { nome_cliente: 'Alice Costa', aniversariante: 'Alice', data_evento: '2026-08-15', horario: '12:00',
      convidados: 30, convidados_meia: 15, dia_tipo: 'sab', valor_pessoa: 149, upgrades: [], desconto: 0,
      validade: '2099-01-01', created_at: new Date().toISOString() };
    const { ctx, page } = await newPage(browser, adminSeed({ propostas: [
      Object.assign({}, propBase, { id: 'p1', token: TK, status: 'rascunho' }),
      Object.assign({}, propBase, { id: 'p2', token: '22222222-2222-4222-8222-222222222222', nome_cliente: 'Bruno Dias', status: 'aceita' })
    ] }));
    await page.goto(BASE + '/admin.html');
    await page.fill('#loginEmail', 'admin@galpe.test');
    await page.fill('#loginPass', 'senha-forte');
    await page.click('#loginBtn');
    await page.waitForSelector('#app', { state: 'visible' });
    await page.click('[data-view="prop"]');
    await page.waitForFunction(() => document.querySelector('#propTable table'));
    const updates = () => page.evaluate(() =>
      window.__MOCK_CALLS.filter(c => c.table === 'propostas' && c.op === 'update'));

    await page.locator('#propTable tr', { hasText: 'Alice Costa' }).locator('button[title="Copiar link"]').click();
    await page.waitForFunction(() => document.getElementById('propTable').textContent.includes('Enviada'));
    const clip = await page.evaluate(() => navigator.clipboard.readText());
    ok(clip === BASE + '/proposta.html?t=' + TK, 'link copiado aponta para proposta.html?t=<token>');
    let ups = await updates();
    ok(ups.length === 1 && ups[0].payload.status === 'enviada' && ups[0].eq[1] === 'p1', 'copiar link promove rascunho → enviada');

    await page.locator('#propTable tr', { hasText: 'Alice Costa' }).locator('button[title="Copiar link"]').click();
    await page.waitForTimeout(400);
    ok((await updates()).length === 1, 'segundo clique (já Enviada) não dispara novo UPDATE');

    await page.locator('#propTable tr', { hasText: 'Bruno Dias' }).locator('button[title="Copiar link"]').click();
    await page.waitForTimeout(400);
    ok((await updates()).length === 1, 'proposta Aceita não sofre UPDATE ao copiar link');
    await ctx.close();
  }

  /* ================= PROPOSTA: estados e falhas do aceite ================= */
  console.log('\n== proposta.html: expirada, recusa da RPC e queda de rede ==');
  {
    // expirada: aviso no lugar do botão
    const rpc = `{ get_proposta: function(){ return { nome_cliente:'Maria', convidados:30, convidados_meia:0, dia_tipo:'sab',
      valor_pessoa:149, upgrades:[], desconto:0, validade:'2020-01-01', status:'enviada' }; } }`;
    const { ctx, page } = await newPage(browser, { site_config: JSON.parse(JSON.stringify(SEED_CONFIG)) }, rpc);
    await page.goto(BASE + '/proposta.html?t=7f0a1bcd-2222-4333-8444-555566667780');
    await page.waitForSelector('#conteudo', { state: 'visible' });
    ok(await page.locator('#btnAceitar').isHidden(), 'proposta vencida esconde o botão de aceite');
    ok((await page.textContent('#avisoIndisp')).includes('venceu em 01/01/2020'), 'aviso de validade vencida com a data');
    ok(await page.locator('#btnWa').isVisible(), 'WhatsApp continua disponível na proposta vencida');
    await ctx.close();
  }
  {
    // RPC recusa (ex.: status rascunho no banco) → mensagem inline, sem alert, botão volta
    const rpc = `{ get_proposta: function(){ return { nome_cliente:'Maria', convidados:30, convidados_meia:0, dia_tipo:'sab',
      valor_pessoa:149, upgrades:[], desconto:0, validade:'2099-01-01', status:'rascunho' }; },
      aceitar_proposta: function(){ return false; } }`;
    const { ctx, page } = await newPage(browser, { site_config: JSON.parse(JSON.stringify(SEED_CONFIG)) }, rpc);
    let alertou = false;
    page.on('dialog', async d => { alertou = true; await d.accept(); });
    await page.goto(BASE + '/proposta.html?t=7f0a1bcd-2222-4333-8444-555566667781');
    await page.waitForSelector('#btnAceitar', { state: 'visible' });
    await page.click('#btnAceitar');
    await page.waitForSelector('#msgErr', { state: 'visible' });
    ok((await page.textContent('#msgErr')).includes('WhatsApp'), 'recusa mostra mensagem inline com saída pelo WhatsApp');
    ok(!alertou, 'sem alert() nativo');
    ok(await page.evaluate(() => !document.getElementById('btnAceitar').disabled), 'botão volta a ficar clicável');
    await ctx.close();
  }
  {
    // queda de rede no aceite → botão não trava em "Enviando…"
    const rpc = `{ get_proposta: function(){ return { nome_cliente:'Maria', convidados:30, convidados_meia:0, dia_tipo:'sab',
      valor_pessoa:149, upgrades:[], desconto:0, validade:'2099-01-01', status:'enviada' }; },
      aceitar_proposta: function(){ return { __reject: true }; } }`;
    const { ctx, page } = await newPage(browser, { site_config: JSON.parse(JSON.stringify(SEED_CONFIG)) }, rpc);
    await page.goto(BASE + '/proposta.html?t=7f0a1bcd-2222-4333-8444-555566667782');
    await page.waitForSelector('#btnAceitar', { state: 'visible' });
    await page.click('#btnAceitar');
    await page.waitForSelector('#msgErr', { state: 'visible' });
    ok((await page.textContent('#msgErr')).includes('conexão'), 'queda de rede mostra "Falha de conexão"');
    ok((await page.textContent('#btnAceitar')).includes('Aceitar'), 'botão não fica preso em "Enviando…"');
    await ctx.close();
  }

  /* ================= INDEX: cookies/LGPD + GA4 + gate ================= */
  console.log('\n== index.html: banner LGPD, GA4 só com aceite, gate de lead ==');
  {
    gtagRequests = []; leadPosts = [];
    const { ctx, page } = await newPage(browser, {});
    await page.goto(BASE + '/index.html');
    await page.waitForSelector('#ckBanner.on');
    ok(true, 'banner de cookies aparece na 1ª visita');
    // recusa: GA não pode carregar mesmo com ga4_id configurado
    await page.click('#ckRecusar');
    await page.waitForTimeout(700);
    ok(await page.evaluate(() => localStorage.getItem('galpe_consent')) === 'essential', 'recusa grava consent=essential');
    ok(gtagRequests.length === 0, 'GA NÃO carregou sem consentimento (0 requests gtag)');
    ok(await page.evaluate(() => !window.gtag), 'window.gtag ausente sem consentimento');
    // reabre preferências e aceita
    await page.click('#ckPrefs');
    await page.waitForSelector('#ckBanner.on');
    ok(true, 'link "Preferências de cookies" reabre o banner');
    await page.click('#ckAceitar');
    await page.waitForFunction(() => window.gtag !== undefined);
    ok(await page.evaluate(() => localStorage.getItem('galpe_consent')) === 'all', 'aceite grava consent=all');
    await page.waitForTimeout(400);
    ok(gtagRequests.some(u => u.includes('G-TEST123')), 'gtag.js requisitado com o ID do Ajustes (G-TEST123)');

    // gate de lead + evento GA
    await page.fill('#gNome', 'Renata Teste');
    await page.fill('#gZap', '21999887766');
    await page.click('#gateGo');
    await page.waitForFunction(() => document.documentElement.classList.contains('lead-ok'));
    ok(true, 'gate libera o simulador');
    ok(leadPosts.length === 1 && leadPosts[0].includes('Renata Teste') && leadPosts[0].includes('"origem":"site"'), 'lead POSTado na REST com origem=site');
    const dl = await page.evaluate(() => (window.dataLayer || []).map(a => Array.prototype.slice.call(a)));
    ok(dl.some(a => a[0] === 'event' && a[1] === 'generate_lead'), 'evento generate_lead no dataLayer');
    // simulador funciona com preços do mock (comida de verdade atualizada p/ 30)
    ok((await page.textContent('#simTot')).includes('R$'), 'simulador calcula total');
    // 2ª visita: banner não volta, simulador já liberado
    await page.goto(BASE + '/index.html');
    await page.waitForTimeout(600);
    ok(!(await page.locator('#ckBanner').evaluate(el => el.classList.contains('on'))), 'banner não reaparece na 2ª visita');
    ok(await page.evaluate(() => document.documentElement.classList.contains('lead-ok')), 'retorno mantém simulador liberado');

    // scrollspy: seção visível marca o link correspondente no nav
    await page.evaluate(() => document.getElementById('precos').scrollIntoView());
    await page.waitForFunction(() => {
      const a = document.querySelector('.nav-links a[href="#precos"]');
      return a && a.classList.contains('ativo');
    });
    ok(true, 'scrollspy marca "Orçamento" ao rolar até #precos');
    ok(await page.evaluate(() => document.querySelector('.nav-links a[href="#precos"]').getAttribute('aria-current') === 'true'), 'link ativo recebe aria-current');
    ok(await page.evaluate(() => document.querySelectorAll('.nav-links a.ativo').length === 1), 'um link ativo por vez');
    await page.evaluate(() => document.getElementById('faq').scrollIntoView());
    await page.waitForFunction(() => {
      const a = document.querySelector('.nav-links a[href="#faq"]');
      return a && a.classList.contains('ativo');
    });
    ok(true, 'scrollspy acompanha a rolagem (#faq vira o ativo)');
    await ctx.close();
  }

  /* ================= privacidade.html ================= */
  {
    const { ctx, page } = await newPage(browser, {});
    await page.goto(BASE + '/privacidade.html');
    ok((await page.textContent('h1')).toLowerCase().includes('privacidade'), 'política de privacidade publica');
    ok((await page.content()).includes('galpe_consent'), 'política documenta os cookies usados');
    await ctx.close();
  }

  await browser.close();
  server.close();

  console.log('\n== erros de página (esperado: nenhum) ==');
  const errosReais = pageErrors.filter(e => !e.includes('net::') );
  errosReais.forEach(e => console.log('  PAGEERROR ' + e));
  ok(errosReais.length === 0, 'zero erros de JS nas páginas');

  console.log(`\n===== RESULTADO: ${passed} ok, ${failed} falhas =====`);
  process.exit(failed ? 1 : 0);
})().catch(e => { console.error('ERRO FATAL', e); process.exit(1); });
