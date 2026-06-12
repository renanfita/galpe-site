/* Mock UMD do supabase-js servido no lugar do CDN durante o E2E.
   Implementa só a superfície usada por admin/proposta/contrato. */
window.__MOCK_CALLS = [];
window.supabase = {
  createClient: function(){
    var db = window.__MOCK_DB || {};
    function table(name){
      var q = { _op: 'select', _payload: null, _eq: null, _single: false };
      q.select = function(){ return q; };
      q.order = function(){ return q; };
      q.single = function(){ q._single = true; return q; };
      q.eq = function(col, val){ q._eq = [col, val]; return q; };
      q.insert = function(p){ q._op = 'insert'; q._payload = p; return q; };
      q.update = function(p){ q._op = 'update'; q._payload = p; return q; };
      q.upsert = function(p){ q._op = 'upsert'; q._payload = p; return q; };
      q.delete = function(){ q._op = 'delete'; return q; };
      q.then = function(res, rej){
        var rows = db[name] || (db[name] = []);
        var out = { data: null, error: null };
        if(q._op === 'select'){
          out.data = rows.slice();
        } else if(q._op === 'insert'){
          var arr = Array.isArray(q._payload) ? q._payload : [q._payload];
          arr.forEach(function(r){
            r.id = r.id || 'id-' + Math.random().toString(36).slice(2);
            if(name === 'propostas' || name === 'contratos') r.token = r.token || crypto.randomUUID();
            r.created_at = r.created_at || new Date().toISOString();
            if(!r.status){
              if(name === 'contratos') r.status = 'rascunho';
              if(name === 'propostas') r.status = 'rascunho';
              if(name === 'leads') r.status = 'novo';
              if(name === 'eventos') r.status = r.status || 'reservado';
            }
            rows.push(r);
          });
          out.data = q._single ? arr[0] : arr;
        } else if(q._op === 'update'){
          rows.forEach(function(r){ if(!q._eq || r[q._eq[0]] === q._eq[1]) Object.assign(r, q._payload); });
        } else if(q._op === 'delete'){
          db[name] = rows.filter(function(r){ return !(q._eq && r[q._eq[0]] === q._eq[1]); });
        }
        window.__MOCK_CALLS.push({ table: name, op: q._op, payload: q._payload, eq: q._eq });
        return Promise.resolve(out).then(res, rej);
      };
      return q;
    }
    return {
      auth: {
        signInWithPassword: function(c){ return Promise.resolve({ data: { user: { email: c.email } }, error: null }); },
        getSession: function(){ return Promise.resolve({ data: { session: null } }); },
        onAuthStateChange: function(){ return { data: { subscription: { unsubscribe: function(){} } } }; },
        signOut: function(){ return Promise.resolve({}); },
        updateUser: function(){ return Promise.resolve({ data: {}, error: null }); }
      },
      from: table,
      rpc: function(fn, params){
        window.__MOCK_CALLS.push({ rpc: fn, params: params });
        var h = window.__MOCK_RPC && window.__MOCK_RPC[fn];
        var data = h ? h(params) : null;
        /* handler devolve {__reject:true} para simular queda de rede */
        if(data && data.__reject) return Promise.reject(new Error('network'));
        return Promise.resolve({ data: data, error: null });
      }
    };
  }
};
