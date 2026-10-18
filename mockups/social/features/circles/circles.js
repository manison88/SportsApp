window.C={sam:'#ffb547',ray:'#8fe3a0',chris:'#ffd36e',jordan:'#6fd3ff',priya:'#ff7a8a',marcus:'#ff9f5a'};
window.PARKS=[["MIN","ray"],["MIL","ray"],["CHC","ray"],["CHW","sam"],["DET","ray"],["TOR","chris"],["CLE","chris"],["PIT","ray"],["NYY","sam"],["NYM","chris"],["BOS","sam"],["PHI","jordan"],["WSH","jordan"],["BAL","chris"],["ATL","chris"],["MIA","marcus"],["TB","marcus"],["HOU","jordan"],["TEX","sam"],["STL","ray"],["KC","sam"],["CIN","ray"],["COL","marcus"],["ARI","jordan"],["LAA","priya"],["LAD","priya"],["SD",null],["SF",null],["ATH","priya"],["SEA",null]];
window.ring=function(svg,size,r,w){
  var n=30,c=size/2,gap=3.2,ns='http://www.w3.org/2000/svg';
  svg.setAttribute('viewBox','0 0 '+size+' '+size);
  PARKS.forEach(function(p,i){
    var a0=(i/n)*360+gap/2-90,a1=((i+1)/n)*360-gap/2-90;
    var x0=c+r*Math.cos(a0*Math.PI/180),y0=c+r*Math.sin(a0*Math.PI/180),x1=c+r*Math.cos(a1*Math.PI/180),y1=c+r*Math.sin(a1*Math.PI/180);
    var e=document.createElementNS(ns,'path');
    e.setAttribute('d','M'+x0+' '+y0+' A'+r+' '+r+' 0 0 1 '+x1+' '+y1);
    e.setAttribute('fill','none');e.setAttribute('stroke-width',w);e.setAttribute('stroke-linecap','butt');
    if(p[1]){e.setAttribute('stroke',C[p[1]]);}else{e.setAttribute('stroke','rgba(245,241,234,.28)');e.setAttribute('stroke-dasharray','2 2.4');}
    svg.appendChild(e);
  });
};
