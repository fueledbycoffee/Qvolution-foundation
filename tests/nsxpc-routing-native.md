# Native NSXPC routing regression

`nsxpc-routing-native.py` extracts two production methods and the object case
of the typed argument decoder without edits. The Linux fixture supplies controlled
transport, serialization, interface and invocation dependencies, using native
libobjc and libdispatch. It checks request/reply class-list selection, transport
queue selection, and nil/non-nil argument retention. It does not exercise Mach
IPC, actual class validation, or object serialization.

Run under the host build slot:

```
dashboard/qv-slot build python3 <foundation>/tests/nsxpc-routing-native.py --out <lane>/native-after
```

Pass `--source-ref <baseline>` to compile the same fixture against the baseline
production regions. Each of `classes`, `queue`, and `nil` fails before the fixes.
The existing `oracle-services/checks/xpc.m` check remains the integration gate:
ten anonymous-listener exchanges followed by client/server invalidation. It must
be rerun through the lane runner before claiming a macOS MATCH.

Contracts: Apple documentation, rung 3:

- https://developer.apple.com/tutorials/data/documentation/foundation/nsxpcconnection/invalidationhandler.json
  requires invalidation on the reply queue and after other callbacks.
- https://developer.apple.com/tutorials/data/documentation/foundation/nsxpcinterface/setclasses(_:for:argumentindex:ofreply:).json
  distinguishes method parameter classes from reply-block parameter classes.

The nil placeholder and invocation retention-array invariant are visible in
the existing NSXPCConnection sender and CoreFoundation NSInvocation source
(rung 2). No external serialization format or new private interface is added.
