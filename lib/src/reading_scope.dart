import 'package:flutter/widgets.dart';

import 'workspace.dart';

/// Visibility of a retained main page. Detail routes outside the workspace
/// remain active by default; retaining a tab never grants background work.
class ReadingScope extends InheritedWidget {
  const ReadingScope({super.key, required this.active, required super.child});

  final bool active;

  static bool isActive(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReadingScope>()?.active ?? true;

  @override
  bool updateShouldNotify(ReadingScope oldWidget) => active != oldWidget.active;
}

/// Revalidates an already visited page when it becomes visible again. Initial
/// loading remains with each page, as do cache, calendar and query semantics.
///
/// Visibility vocabulary, one meaning per name:
/// - [readingActive]: the owner's selected main tab (may be covered by a route).
/// - [readingVisible]: that tab's route is on top, so the page is on screen.
/// - [readingPresent]: on screen, or covered only by an editor this page opened.
/// - [readingWasVisible]: [readingVisible] as of the last dependency pass.
mixin ReadingLifecycle<T extends StatefulWidget> on State<T> {
  bool? _wasActive, _wasVisible;
  int _editors = 0;
  bool _editorClosed = false;
  bool get readingActive => ReadingScope.isActive(context);

  /// Foreground work belongs to the visible tab while its route is on top, so
  /// a covered or hidden page never refreshes, paginates or prefetches.
  bool get readingVisible =>
      readingActive && (ModalRoute.of(context)?.isCurrent ?? false);

  /// Visibility recorded by the last dependency pass. Safe to read from
  /// [didUpdateWidget], which must not register a new inherited dependency.
  bool get readingWasVisible => _wasVisible ?? readingActive;

  /// The owner's current reading context: the visible page itself, or a modal
  /// editor this page opened over it (date picker, fee sheet, filter dialog).
  /// A page covered by a detail route is neither, so it stays passive.
  bool get readingPresent => readingVisible || _editors > 0;

  Future<void> resumeReading();

  /// True while a cost change (or similar) is waiting for a visible frame.
  /// Route returns always revalidate pages that deferred work, so a deferred
  /// fee refresh is never lost behind a closed sheet or a detail route.
  bool get readingDeferred => false;

  /// Runs a modal editor that belongs to this page. Its own completion path
  /// refreshes the same query, so closing it is not a reading-route return and
  /// must not trigger a second read of that query.
  Future<R> readingEditor<R>(Future<R> Function() open) async {
    _editors++;
    try {
      return await open();
    } finally {
      _editors--;
      // The editor's own completion already read its query; note the close so
      // the visible frame it returns to does not read that query a second time.
      _editorClosed = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active =
        context.dependOnInheritedWidgetOfExactType<ReadingScope>()?.active ??
        true;
    final visible = active && (ModalRoute.of(context)?.isCurrent ?? false);
    // A detail route covers the workspace without deactivating the tab. Both
    // transitions end in the same visible revalidation, while hiding never
    // grants background work.
    final tabReturned = _wasActive == false && active;
    final routeReturned = _wasVisible == false && visible;
    final first = _wasActive == null;
    // Being covered again starts a new reading frame, so a close note from an
    // earlier editor can never suppress that later return.
    if (!visible) _editorClosed = false;
    final returned = !first && (tabReturned || routeReturned);
    final editorClosed = _editorClosed;
    if (returned) _editorClosed = false;
    _wasActive = active;
    _wasVisible = visible;
    if (returned && (readingDeferred || (!editorClosed && _editors == 0))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && readingVisible) resumeReading();
      });
    }
  }
}

/// A retained page that owns charge-derived snapshots. The workspace bumps
/// [VehicleWorkspace.costRevision] when an entered fee invalidates them; the
/// page defers while hidden or covered, then consumes the revision with one
/// forced revalidation on its next visible frame. #25 extends this contract.
mixin CostAwareReading<T extends StatefulWidget>
    on State<T>, ReadingLifecycle<T> {
  VehicleWorkspace get workspace;
  bool _deferredCost = false;
  int _costRevision = 0;

  bool get costPending =>
      _deferredCost || _costRevision != workspace.costRevision;

  void initCostReading() => _costRevision = workspace.costRevision;
  void deferCost() => _deferredCost = true;

  void consumeCost() {
    _deferredCost = false;
    _costRevision = workspace.costRevision;
  }

  @override
  bool get readingDeferred => _deferredCost;
}
