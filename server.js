(function(){var e,t,r,n,i,o,a,s,c;n=require("fs"),o=require("path"),i=require("http"),t={css:"text/css",html:"text/html",js:"text/javascript",json:"application/json"},e={EACCES:[403,"Forbidden"],ENOENT:[404,"Not found"],DEFAULT:[500,"Internal server error"]},r="dist",s=function(i,a){var s,c;s=t[o.extname(a).substr(1)]||"text/plain",a=r+a,c=n.createReadStream(a),c.on("error",function(t){var r;r=e[t.code]||e.DEFAULT,i.writeHead(r[0],{"Content-Type":"text/plain"}),i.end(""+r[0]+" "+r[1])}),i.writeHead(200,{"Content-Type":s}),c.pipe(i)},c=i.createServer(function(e,t){var r;r=e.url,"/"===r&&(r="/index.html"),s(t,r)}),a=Number(process.env.PORT||8888),c.listen(a),console.log("listening on port "+a)}).call(this);