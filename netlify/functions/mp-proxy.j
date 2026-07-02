// Netlify Function — Proxy para API de Mercado Público
// Evita el bloqueo CORS del navegador

const TICKET = 'BB555465-BB26-4427-A97D-3576980D3B85';
const BASE_LICIT = 'https://api.mercadopublico.cl/servicios/v1/publico/licitaciones.json';
const BASE_OC    = 'https://api.mercadopublico.cl/servicios/v1/publico/ordenesdecompra.json';

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

function getFecha(diasAtras) {
  const d = new Date();
  d.setDate(d.getDate() - diasAtras);
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  return `${dd}${mm}${d.getFullYear()}`;
}

async function fetchDia(base, fecha) {
  try {
    const url = new URL(base);
    url.searchParams.set('ticket', TICKET);
    url.searchParams.set('fecha', fecha);
    const r = await fetch(url.toString());
    const data = await r.json();
    return data?.Listado || [];
  } catch {
    return [];
  }
}

exports.handler = async function(event) {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: CORS, body: '' };
  }

  try {
    const params = event.queryStringParameters || {};
    const tipo   = params.tipo || 'licitaciones';
    const dias   = parseInt(params.dias || '30');
    const fecha  = params.fecha;
    const codigo = params.codigo;
    const BASE   = tipo === 'agiles' ? BASE_OC : BASE_LICIT;

    // Consulta específica
    if (fecha || codigo) {
      const url = new URL(BASE);
      url.searchParams.set('ticket', TICKET);
      if (fecha)  url.searchParams.set('fecha',  fecha);
      if (codigo) url.searchParams.set('codigo', codigo);
      const resp = await fetch(url.toString());
      const text = await resp.text();
      return { statusCode: 200, headers: { ...CORS, 'Content-Type': 'application/json' }, body: text };
    }

    // Batch — todos los días en paralelo
    const promesas = Array.from({ length: dias }, (_, i) => fetchDia(BASE, getFecha(i)));
    const resultados = await Promise.all(promesas);

    const vistas = new Set();
    const listado = [];
    for (const items of resultados) {
      for (const item of items) {
        const key = item.CodigoExterno || item.Numero || item.ID || Math.random().toString();
        if (!vistas.has(key)) { vistas.add(key); listado.push(item); }
      }
    }

    return {
      statusCode: 200,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ Cantidad: listado.length, Listado: listado })
    };

  } catch (err) {
    return {
      statusCode: 500,
      headers: CORS,
      body: JSON.stringify({ error: String(err) })
    };
  }
};
  
