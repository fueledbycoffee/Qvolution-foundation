#!/usr/bin/env python3
"""Run the production wait-status conversion against real native child exits.
This isolates conversion; it does not test NSTask's dispatch monitor.
"""
import argparse
from pathlib import Path
import re
import subprocess
p = argparse.ArgumentParser()
p.add_argument('--revision')
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
s = subprocess.check_output(['git', '-C', str(root), 'show', a.revision + ':src/NSTask.m'], text=True) if a.revision else (root/'src/NSTask.m').read_text()
region = s[s.index('waitpid(_pid, &status, 0);'):]
conversion = '\n'.join(re.findall(r'_code = [^;]+;|_reason = [^;]+;', region)[:2])
assert '_code =' in conversion and '_reason =' in conversion
a.out.mkdir(parents=True, exist_ok=True)
source = r'''
#include <sys/wait.h>
#include <unistd.h>
#include <signal.h>
#include <stdio.h>
#include <errno.h>
enum { NSTaskTerminationReasonExit=1, NSTaskTerminationReasonUncaughtSignal=2 };
int main(void) {
    const int exits[]={0,7,42};
    int failures=0;
    for(int i=0;i<5;i++) {
        pid_t child=fork();
        if(child<0)return 2;
        int sig=i==3?SIGTERM:SIGKILL;
        if(!child) {
            if(i<3)_exit(exits[i]);
            signal(sig,SIG_DFL);raise(sig);_exit(99);
        }
        int status=0;while(waitpid(child,&status,0)<0)if(errno!=EINTR)return 3;
        int _code=-1,_reason=0;
        CONVERSION
        int expected=i<3?exits[i]:sig;
        int reason=i<3?NSTaskTerminationReasonExit:NSTaskTerminationReasonUncaughtSignal;
        printf("case %d: status=%d reason=%d expected=%d/%d\n",i,_code,_reason,expected,reason);
        if(_code!=expected||_reason!=reason)failures++;
    }
    return failures?1:0;
}
'''.replace('CONVERSION', conversion)
(a.out/'task-status.c').write_text(source)
subprocess.run(['/usr/bin/clang', '-Wall', '-Werror', str(a.out/'task-status.c'), '-o', str(a.out/'task-status')], check=True)
raise SystemExit(subprocess.run([str(a.out/'task-status')]).returncode)
