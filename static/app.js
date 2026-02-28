$(document).on('ready turbolinks:load', function () {
    // This is called on the first page load *and* also when the page is changed by turbolinks
});

// IHP AutoRefresh keeps current input/select values during morphdom updates.
// That is helpful for forms, but for roster we want remote updates to be visible live.
// We keep default behavior globally and only disable value-preservation within `.roster-grid`.
(function enableRosterGridAutoRefreshSync() {
    if (typeof window === 'undefined' || typeof window.morphdom !== 'function') return;

    const baseMorphdom = window.morphdom;
    window.morphdom = function (fromNode, toNode, options) {
        if (options && typeof options.onBeforeElChildrenUpdated === 'function') {
            const baseHook = options.onBeforeElChildrenUpdated;
            options = {
                ...options,
                onBeforeElChildrenUpdated: function (fromEl, toEl) {
                    const isRosterControl =
                        fromEl instanceof HTMLElement &&
                        fromEl.closest('.roster-grid') &&
                        (fromEl.tagName === 'INPUT' || fromEl.tagName === 'SELECT' || fromEl.tagName === 'TEXTAREA');

                    if (isRosterControl) {
                        return;
                    }

                    return baseHook(fromEl, toEl);
                },
            };
        }

        return baseMorphdom(fromNode, toNode, options);
    };
})();
