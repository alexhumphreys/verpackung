x = function format(proc)
  {console.log(proc);
   return JSON.stringify(
      { status: proc.status
      , stdout: ''
      , stderr: ''
      }
    );
  }(require('child_process').spawnSync('ls'))

const timer = ms => new Promise( res => setTimeout(res, ms));
console.log("wait 3 seconds")
timer(6000).then(_=>console.log("done"));
console.log(x)
