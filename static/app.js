$(document).on('ready turbolinks:load', function () {
    // This is called on the first page load *and* also when the page is changed by turbolinks
});

// Defer auto-refresh updates for rows that are actively being edited.
// This prevents in-progress edits from being clobbered by live updates while still replaying the latest row after blur.
(function enableRosterGridAutoRefreshDeferral() {
    if (typeof window === 'undefined' || typeof window.morphdom !== 'function') return;

    const pendingRows = new Map();
    const baseMorphdom = window.morphdom;

    function hasActiveRosterInput(rowEl) {
        return Boolean(rowEl.querySelector('.slot-cell-input:focus'));
    }

    function applyPendingRow(rowId) {
        const pendingMarkup = pendingRows.get(rowId);
        if (!pendingMarkup) return;

        const currentRow = document.getElementById(rowId);
        if (!currentRow) {
            pendingRows.delete(rowId);
            return;
        }

        const template = document.createElement('template');
        template.innerHTML = pendingMarkup.trim();
        const nextRow = template.content.firstElementChild;
        if (!nextRow) {
            pendingRows.delete(rowId);
            return;
        }

        pendingRows.delete(rowId);
        baseMorphdom(currentRow, nextRow);
    }

    window.morphdom = function (fromNode, toNode, options) {
        const baseOnBeforeElUpdated = options && typeof options.onBeforeElUpdated === 'function'
            ? options.onBeforeElUpdated
            : null;
        const baseOnBeforeElChildrenUpdated = options && typeof options.onBeforeElChildrenUpdated === 'function'
            ? options.onBeforeElChildrenUpdated
            : null;

        if (options) {
            options = {
                ...options,
                onBeforeElChildrenUpdated: function (fromEl, toEl) {
                    const isRosterControl =
                        fromEl instanceof HTMLElement &&
                        fromEl.closest('.roster-grid') &&
                        (fromEl.tagName === 'INPUT'
                            || fromEl.tagName === 'SELECT'
                            || fromEl.tagName === 'TEXTAREA'
                            || fromEl.tagName === 'OPTION');

                    // Skip IHP's value-preservation hook for roster controls so server truth is reflected.
                    if (isRosterControl) {
                        return;
                    }

                    if (baseOnBeforeElChildrenUpdated) {
                        return baseOnBeforeElChildrenUpdated(fromEl, toEl);
                    }

                    return true;
                },
                onBeforeElUpdated: function (fromEl, toEl) {
                    if (baseOnBeforeElUpdated && baseOnBeforeElUpdated(fromEl, toEl) === false) {
                        return false;
                    }

                    const isRosterRow =
                        fromEl instanceof HTMLElement &&
                        toEl instanceof HTMLElement &&
                        fromEl.matches('tr[data-roster-row]') &&
                        toEl.matches('tr[data-roster-row]');

                    if (isRosterRow && hasActiveRosterInput(fromEl)) {
                        const rowId = fromEl.id;
                        if (rowId) {
                            pendingRows.set(rowId, toEl.outerHTML);
                        }
                        return false;
                    }

                    return true;
                },
            };
        }

        return baseMorphdom(fromNode, toNode, options);
    };

    document.addEventListener('focusout', function (event) {
        const target = event.target;
        if (!(target instanceof HTMLElement)) return;
        if (!target.classList.contains('slot-cell-input')) return;

        const rowEl = target.closest('tr[data-roster-row]');
        if (!rowEl || !rowEl.id) return;

        // Wait until focus has potentially moved to another input in the same row.
        window.setTimeout(function () {
            if (!hasActiveRosterInput(rowEl)) {
                applyPendingRow(rowEl.id);
            }
        }, 0);
    });
})();

// HTMX and IHP AutoRefresh can race and apply overlapping DOM updates.
// Pause AutoRefresh while an HTMX request is in-flight and briefly during settle.
(function pauseAutoRefreshDuringHtmxRequests() {
    if (typeof window === 'undefined') return;

    let inFlightRequests = 0;
    let resumeTimer = null;

    function pauseNow() {
        if (typeof window.pauseAutoRefresh === 'function') {
            window.pauseAutoRefresh();
            return;
        }
        if ('autoRefreshPaused' in window) {
            window.autoRefreshPaused = true;
        }
    }

    function scheduleResume() {
        if (resumeTimer) {
            window.clearTimeout(resumeTimer);
        }
        resumeTimer = window.setTimeout(function () {
            if (inFlightRequests === 0 && 'autoRefreshPaused' in window) {
                window.autoRefreshPaused = false;
            }
        }, 150);
    }

    document.body.addEventListener('htmx:beforeRequest', function () {
        inFlightRequests += 1;
        pauseNow();
    });

    function onRequestDone() {
        if (inFlightRequests > 0) {
            inFlightRequests -= 1;
        }
        scheduleResume();
    }

    document.body.addEventListener('htmx:afterRequest', onRequestDone);
    document.body.addEventListener('htmx:responseError', onRequestDone);
    document.body.addEventListener('htmx:sendError', onRequestDone);
    document.body.addEventListener('htmx:swapError', onRequestDone);
    document.body.addEventListener('htmx:afterSettle', function () {
        scheduleResume();
    });
})();
