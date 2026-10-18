
const COL={baseball:'#FF5A4F',football:'#3DDC84',basketball:'#FFA42E',hockey:'#5AC8FA',soccer:'#E6F05A',motorsport:'#BF7BFF',handball:'#FF7AD1'};
function rr(ctx,x,y,w,h,r){ctx.beginPath();ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath();}
function venueGlyph(cv,sport,px){
  const S=px*3;cv.width=S;cv.height=S;cv.style.width=px+'px';cv.style.height=px+'px';
  const c=cv.getContext('2d');const w=S,h=S;
  c.fillStyle='#1b1b20';rr(c,0,0,w,h,w*.28);c.fill();
  const bx=w*.1,by=h*.18,bw=w*.8,bh=h*.64;
  c.strokeStyle='rgba(255,255,255,.28)';c.lineWidth=w*.07;rr(c,bx,by,bw,bh,bh/2);c.stroke();
  const ix=bx+w*.1,iy=by+h*.1,iw=bw-w*.2,ih=bh-h*.2;
  c.strokeStyle='rgba(255,255,255,.14)';c.lineWidth=w*.04;rr(c,ix,iy,iw,ih,ih/2);c.stroke();
  const fx=ix+w*.07,fy=iy+h*.05,fw=iw-w*.14,fh=ih-h*.1;const line=COL[sport]||'#fff';const lw=Math.max(w*.032,1);
  c.strokeStyle=line;c.lineWidth=lw;
  const fillA=(a)=>{c.fillStyle=line;c.globalAlpha=a;};
  if(sport==='baseball'){fillA(.18);c.beginPath();c.ellipse(fx+fw/2,fy+fh/2,fw*.48,fh/2,0,0,7);c.fill();c.globalAlpha=1;
    const cx=fx+fw/2,cy=fy+fh-fh*.08,r=fh*.42;c.beginPath();c.moveTo(cx,cy);c.lineTo(cx+r,cy-r);c.lineTo(cx,cy-2*r);c.lineTo(cx-r,cy-r);c.closePath();c.stroke();}
  else if(sport==='football'){fillA(.18);rr(c,fx,fy,fw,fh,2);c.fill();c.globalAlpha=1;rr(c,fx,fy,fw,fh,2);c.stroke();c.globalAlpha=.7;c.lineWidth=lw*.7;for(let i=1;i<5;i++){const x=fx+fw*i/5;c.beginPath();c.moveTo(x,fy);c.lineTo(x,fy+fh);c.stroke();}c.globalAlpha=1;}
  else if(sport==='basketball'||sport==='handball'){rr(c,fx,fy,fw,fh,2);c.stroke();c.globalAlpha=.8;c.lineWidth=lw*.8;c.beginPath();c.moveTo(fx+fw/2,fy);c.lineTo(fx+fw/2,fy+fh);c.stroke();c.globalAlpha=1;const k=fh*.46;c.strokeRect(fx,fy+fh/2-k/2,fw*.22,k);c.strokeRect(fx+fw-fw*.22,fy+fh/2-k/2,fw*.22,k);}
  else if(sport==='hockey'){rr(c,fx,fy,fw,fh,fh*.35);c.stroke();c.strokeStyle='rgba(255,60,60,.8)';c.lineWidth=lw*.8;c.beginPath();c.moveTo(fx+fw/2,fy);c.lineTo(fx+fw/2,fy+fh);c.stroke();c.strokeStyle=line;c.globalAlpha=.8;c.beginPath();c.arc(fx+fw/2,fy+fh/2,fh*.2,0,7);c.stroke();c.globalAlpha=1;}
  else if(sport==='motorsport'){c.lineWidth=lw*1.6;c.lineCap='round';c.lineJoin='round';c.beginPath();c.moveTo(fx+fw*.1,fy+fh/2);c.bezierCurveTo(fx,fy,fx+fw*.3,fy,fx+fw/2,fy);c.bezierCurveTo(fx+fw/2+fw*.3,fy,fx+fw,fy+fh/2-fh*.3,fx+fw*.95,fy+fh/2+fh*.1);c.bezierCurveTo(fx+fw,fy+fh,fx+fw/2+fw*.2,fy+fh,fx+fw/2,fy+fh);c.bezierCurveTo(fx+fw*.2,fy+fh,fx,fy+fh,fx+fw*.1,fy+fh/2);c.stroke();}
  else{fillA(.18);rr(c,fx,fy,fw,fh,2);c.fill();c.globalAlpha=1;rr(c,fx,fy,fw,fh,2);c.stroke();c.globalAlpha=.8;c.lineWidth=lw*.8;c.beginPath();c.moveTo(fx+fw/2,fy);c.lineTo(fx+fw/2,fy+fh);c.stroke();c.beginPath();c.arc(fx+fw/2,fy+fh/2,fh*.22,0,7);c.stroke();c.globalAlpha=1;}
}
function centerOf(code){const it=SHAPES.find(s=>s.c===code);if(!it)return[0,20];const ring=it.r.reduce((a,b)=>b.length>a.length?b:a);let sx=0,sy=0,la=0,n=ring.length/2;for(let i=0;i<ring.length;i+=2){const lo=ring[i]/10*Math.PI/180;sx+=Math.cos(lo);sy+=Math.sin(lo);la+=ring[i+1]/10;}return[Math.atan2(sy,sx)*180/Math.PI,la/n];}
function globe(cv,code,px){
  const S=px*3;cv.width=S;cv.height=S;cv.style.width=px+'px';cv.style.height=px+'px';const c=cv.getContext('2d');
  const r=S/2-3,cx=S/2,cy=S/2;c.fillStyle='#1b1b20';c.beginPath();c.arc(cx,cy,r,0,7);c.fill();
  const [lo0,la0d]=centerOf(code);const lon0=lo0*Math.PI/180,lat0=la0d*Math.PI/180;
  const it0=SHAPES.find(s=>s.c===code);let ext=0;if(it0){for(const ring of it0.r)for(let i=0;i<ring.length;i+=2){const lam=ring[i]/10*Math.PI/180-lon0,phi=ring[i+1]/10*Math.PI/180;const d=Math.acos(Math.min(1,Math.max(-1,Math.sin(lat0)*Math.sin(phi)+Math.cos(lat0)*Math.cos(phi)*Math.cos(lam))));ext=Math.max(ext,d);}}
  const zoom=it0?Math.min(Math.max(0.55/Math.max(Math.sin(Math.min(ext,1.4)),0.01),1),7):1;
  c.save();c.beginPath();c.arc(cx,cy,r,0,7);c.clip();
  const proj=(lo,la)=>{const lam=lo*Math.PI/180-lon0,phi=la*Math.PI/180;const vis=Math.sin(lat0)*Math.sin(phi)+Math.cos(lat0)*Math.cos(phi)*Math.cos(lam);if(vis<=0)return null;return[cx+Math.cos(phi)*Math.sin(lam)*r*zoom,cy-(Math.cos(lat0)*Math.sin(phi)-Math.sin(lat0)*Math.cos(phi)*Math.cos(lam))*r*zoom];};
  c.strokeStyle='rgba(255,255,255,.10)';c.lineWidth=1.2;
  for(let la=-60;la<=60;la+=30){c.beginPath();let st=false;for(let lo=-180;lo<=180;lo+=6){const q=proj(lo,la);if(q){st?c.lineTo(q[0],q[1]):c.moveTo(q[0],q[1]);st=true}else st=false}c.stroke();}
  for(let lo=-180;lo<180;lo+=30){c.beginPath();let st=false;for(let la=-90;la<=90;la+=6){const q=proj(lo,la);if(q){st?c.lineTo(q[0],q[1]):c.moveTo(q[0],q[1]);st=true}else st=false}c.stroke();}
  const draw=(it,fill)=>{c.fillStyle=fill;for(const ring of it.r){c.beginPath();let any=false;for(let i=0;i<ring.length;i+=2){const q=proj(ring[i]/10,ring[i+1]/10);if(!q)continue;any?c.lineTo(q[0],q[1]):c.moveTo(q[0],q[1]);any=true}if(any){c.closePath();c.fill();}}};
  for(const it of SHAPES)if(it.c!==code)draw(it,'rgba(255,255,255,.22)');
  const me=SHAPES.find(s=>s.c===code);if(me)draw(me,'#F7D64A');c.restore();
  c.strokeStyle='rgba(255,255,255,.35)';c.lineWidth=2;c.beginPath();c.arc(cx,cy,r,0,7);c.stroke();
}
