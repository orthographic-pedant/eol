/*
Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/
!function(){function e(e){return CKEDITOR.env.ie?e.$.clientWidth:parseInt(e.getComputedStyle("width"),10)}function t(e,t){var i=e.getComputedStyle("border-"+t+"-width"),n={thin:"0px",medium:"1px",thick:"2px"};return i.indexOf("px")<0&&(i=i in n&&"none"!=e.getComputedStyle("border-style")?n[i]:0),parseInt(i,10)}function i(e){for(var t,i,n,a=e.$.rows,o=0,r=0,s=a.length;s>r;r++)n=a[r],t=n.cells.length,t>o&&(o=t,i=n);return i}function n(e){for(var n=[],a=-1,o="rtl"==e.getComputedStyle("direction"),r=i(e),s=new CKEDITOR.dom.element(e.$.tBodies[0]),l=s.getDocumentPosition(),c=0,d=r.cells.length;d>c;c++){var u=new CKEDITOR.dom.element(r.cells[c]),p=r.cells[c+1]&&new CKEDITOR.dom.element(r.cells[c+1]);a+=u.$.colSpan||1;var h,m,g,f=u.getDocumentPosition().x;o?m=f+t(u,"left"):h=f+u.$.offsetWidth-t(u,"right"),p?(f=p.getDocumentPosition().x,o?h=f+p.$.offsetWidth-t(p,"right"):m=f+t(p,"left")):(f=e.getDocumentPosition().x,o?h=f:m=f+e.$.offsetWidth),g=Math.max(m-h,3),n.push({table:e,index:a,x:h,y:l.y,width:g,height:s.$.offsetHeight,rtl:o})}return n}function a(e,t){for(var i=0,n=e.length;n>i;i++){var a=e[i];if(t>=a.x&&t<=a.x+a.width)return a}return null}function o(e){(e.data||e).preventDefault()}function r(i){function n(){h=null,b=0,f=0,m.removeListener("mouseup",u),g.removeListener("mousedown",d),g.removeListener("mousemove",p),m.getBody().setStyle("cursor","auto"),c?g.remove():g.hide()}function a(){for(var t=h.index,i=CKEDITOR.tools.buildTableMap(h.table),n=[],a=[],r=Number.MAX_VALUE,s=r,l=h.rtl,c=0,d=i.length;d>c;c++){var u=i[c],T=u[t+(l?1:0)],_=u[t+(l?0:1)];T=T&&new CKEDITOR.dom.element(T),_=_&&new CKEDITOR.dom.element(_),T&&_&&T.equals(_)||(T&&(r=Math.min(r,e(T))),_&&(s=Math.min(s,e(_))),n.push(T),a.push(_))}y=n,k=a,w=h.x-r,C=h.x+s,g.setOpacity(.5),v=parseInt(g.getStyle("left"),10),b=0,f=1,g.on("mousemove",p),m.on("dragstart",o)}function r(){f=0,g.setOpacity(0),b&&s();var e=h.table;setTimeout(function(){e.removeCustomData("_cke_table_pillars")},0),m.removeListener("dragstart",o)}function s(){for(var i=h.rtl,n=i?k.length:y.length,a=0;n>a;a++){var o=y[a],r=k[a],s=h.table;CKEDITOR.tools.setTimeout(function(e,t,n,a,o,r){e&&e.setStyle("width",l(Math.max(t+r,0))),n&&n.setStyle("width",l(Math.max(a-r,0))),o&&s.setStyle("width",l(o+r*(i?-1:1)))},0,this,[o,o&&e(o),r,r&&e(r),(!o||!r)&&e(s)+t(s,"left")+t(s,"right"),b])}}function d(e){o(e),a(),m.on("mouseup",u,this)}function u(e){e.removeListener(),r()}function p(e){T(e.data.$.clientX)}var h,m,g,f,v,b,y,k,w,C;m=i.document,g=CKEDITOR.dom.element.createFromHtml('<div data-cke-temp=1 contenteditable=false unselectable=on style="position:absolute;cursor:col-resize;filter:alpha(opacity=0);opacity:0;padding:0;background-color:#004;background-image:none;border:0px none;z-index:10"></div>',m),c||m.getDocumentElement().append(g),this.attachTo=function(e){f||(c&&(m.getBody().append(g),b=0),h=e,g.setStyles({width:l(e.width),height:l(e.height),left:l(e.x),top:l(e.y)}),c&&g.setOpacity(.25),g.on("mousedown",d,this),m.getBody().setStyle("cursor","col-resize"),g.show())};var T=this.move=function(e){if(!h)return 0;if(!f&&(e<h.x||e>h.x+h.width))return n(),0;var t=e-Math.round(g.$.offsetWidth/2);if(f){if(t==w||t==C)return 1;t=Math.max(t,w),t=Math.min(t,C),b=t-v}return g.setStyle("left",l(t)),1}}function s(e){var t=e.data.getTarget();if("mouseout"==e.name){if(!t.is("table"))return;for(var i=new CKEDITOR.dom.element(e.data.$.relatedTarget||e.data.$.toElement);i&&i.$&&!i.equals(t)&&!i.is("body");)i=i.getParent();if(!i||i.equals(t))return}t.getAscendant("table",1).removeCustomData("_cke_table_pillars"),e.removeListener()}var l=CKEDITOR.tools.cssLength,c=CKEDITOR.env.ie&&(CKEDITOR.env.ie7Compat||CKEDITOR.env.quirks||CKEDITOR.env.version<7);CKEDITOR.plugins.add("tableresize",{requires:["tabletools"],init:function(e){e.on("contentDom",function(){var t;e.document.getBody().on("mousemove",function(i){if(i=i.data,t&&t.move(i.$.clientX))return o(i),void 0;var l,c,d=i.getTarget();if(d.is("table")||d.getAscendant("tbody",1)){l=d.getAscendant("table",1),(c=l.getCustomData("_cke_table_pillars"))||(l.setCustomData("_cke_table_pillars",c=n(l)),l.on("mouseout",s),l.on("mousedown",s));var u=a(c,i.$.clientX);u&&(!t&&(t=new r(e)),t.attachTo(u))}})})}})}();