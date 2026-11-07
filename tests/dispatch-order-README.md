# Dispatch ordering contract regression

Run the standalone ARC Objective-C check with Foundation, CoreFoundation and
blocks on macOS and run the same binary on Darling. The lane command is:

    QV_RUN=1 /home/sean/Documents/Codex/Projects/Qvolution-work/parallel/fx-order-2/run-qvdiff.sh

Rung 3: Apple documents asyncAfter as scheduling execution at the specified
time, returning immediately. It does not specify a relative order among
independently scheduled timers with equal deadlines:
https://developer.apple.com/tutorials/data/documentation/dispatch/dispatchqueue/asyncafter(deadline:execute:).json

Rung 3: serial dispatch queues execute queued work FIFO and one task at a time:
https://developer.apple.com/tutorials/data/documentation/dispatch/dispatchqueue.json
Timer delivery order is distinct from the FIFO order once work is submitted.
The check keeps exact-order facts for direct queue submissions and nested work.

Rung 4: the lane's 20-process stability batch
20261107T112358Z-dispatch-stability-checks_-902651 observed A,B,C 15 times and
A,C,B 5 times on macOS 12.7.6. The unchanged check again failed at precisely
main-after-equal in batch 20261107T131950Z-checks_-1238449. An exact timer-tie
permutation therefore cannot be the differential contract.

For both main and private serial queues, equal-deadline scenarios now compare
callback membership, still retaining the raw order as an ignored diagnostic.
All six permutations are valid; self-tests reject absent, missing, duplicate,
unexpected and extra callbacks. The executable also fails for incomplete
delivery, wrong queue/thread, overlapping callback execution or execution
before the requested deadline. Counts and submission-time facts remain.
No production libdispatch behavior is changed to fit a sampled permutation.
