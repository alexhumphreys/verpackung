var x = require('child_process').spawnSync("ls");

console.log(
  JSON.stringify({ status:x.status
  , stdout:x.output[1].toString()
  , stdrr:x.output[2].toString()
  })
);

function doit(str) {
  return function format(proc) {
    return JSON.stringify({status: proc.status});
  }(require('child_process').spawnSync(str))
}

console.log(doit("ls"));
