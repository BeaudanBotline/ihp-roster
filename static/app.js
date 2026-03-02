$(document).on('ready turbolinks:load', function () {
    // This is called on the first page load *and* also when the page is changed by turbolinks
    if (window.htmx && typeof window.htmx.process === 'function') {
        window.htmx.process(document.body);
    }
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
    const eventTarget = document;

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

    eventTarget.addEventListener('htmx:beforeRequest', function () {
        inFlightRequests += 1;
        pauseNow();
    });

    function onRequestDone() {
        if (inFlightRequests > 0) {
            inFlightRequests -= 1;
        }
        scheduleResume();
    }

    eventTarget.addEventListener('htmx:afterRequest', onRequestDone);
    eventTarget.addEventListener('htmx:responseError', onRequestDone);
    eventTarget.addEventListener('htmx:sendError', onRequestDone);
    eventTarget.addEventListener('htmx:swapError', onRequestDone);
    eventTarget.addEventListener('htmx:afterSettle', function () {
        scheduleResume();
    });
})();

// Reusable quarter-hour modal time picker.
// Any field using [data-time-picker-field] + .js-time-picker-input + .js-time-picker-trigger
// can opt into this behavior.
(function enableQuarterHourTimePicker() {
    if (typeof window === 'undefined') return;

    const modalId = 'quarter-hour-time-picker-modal';
    const emptyLabel = 'Select time';
    let activeField = null;

    function getModalElement() {
        return document.getElementById(modalId);
    }

    function getBootstrapModal(modalEl) {
        if (!modalEl || !window.bootstrap || !window.bootstrap.Modal) return null;
        return window.bootstrap.Modal.getOrCreateInstance(modalEl);
    }

    function getFieldInput(fieldEl) {
        return fieldEl ? fieldEl.querySelector('.js-time-picker-input') : null;
    }

    function getFieldLabel(fieldEl) {
        return fieldEl ? fieldEl.querySelector('.js-time-picker-label') : null;
    }

    function findOptionByValue(modalEl, value) {
        if (!modalEl) return null;
        return modalEl.querySelector(`.js-time-picker-option[data-time-value="${value}"]`);
    }

    function minuteOfDayFromValue(value) {
        if (!value || !/^\d{2}:\d{2}$/.test(value)) return null;
        const parts = value.split(':');
        const hour = Number(parts[0]);
        const minute = Number(parts[1]);
        if (!Number.isInteger(hour) || !Number.isInteger(minute)) return null;
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return hour * 60 + minute;
    }

    function displayLabelFromValue(value) {
        const minuteOfDay = minuteOfDayFromValue(value);
        if (minuteOfDay === null) return value;

        const hour24 = Math.floor(minuteOfDay / 60);
        const minute = minuteOfDay % 60;
        const meridiem = hour24 >= 12 ? 'PM' : 'AM';
        const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;
        const minuteLabel = String(minute).padStart(2, '0');
        return `${hour12}:${minuteLabel} ${meridiem}`;
    }

    function resolveRange(fieldEl, modalEl) {
        const defaultStart = (modalEl && modalEl.dataset.defaultStartTime) || '06:00';
        const defaultEnd = (modalEl && modalEl.dataset.defaultEndTime) || '23:45';
        const startValue = (fieldEl && fieldEl.dataset.timePickerStart) || defaultStart;
        const endValue = (fieldEl && fieldEl.dataset.timePickerEnd) || defaultEnd;

        const startMinute = minuteOfDayFromValue(startValue);
        const endMinuteRaw = minuteOfDayFromValue(endValue);
        if (startMinute === null || endMinuteRaw === null) return null;

        const endMinute = endMinuteRaw < startMinute ? endMinuteRaw + 24 * 60 : endMinuteRaw;
        return { startMinute, endMinute };
    }

    function buildTimeOptions(range) {
        if (!range) return [];

        const options = [];
        for (let minute = range.startMinute; minute <= range.endMinute; minute += 15) {
            const minuteOfDay = minute % (24 * 60);
            const hour = Math.floor(minuteOfDay / 60);
            const minutePart = minuteOfDay % 60;
            const value = `${String(hour).padStart(2, '0')}:${String(minutePart).padStart(2, '0')}`;
            options.push({ value, label: displayLabelFromValue(value) });
        }
        return options;
    }

    function renderOptions(modalEl, range) {
        if (!modalEl) return;
        const gridEl = modalEl.querySelector('.js-time-picker-grid');
        if (!gridEl) return;

        const options = buildTimeOptions(range);
        gridEl.innerHTML = options
            .map(function (option) {
                return (
                    `<button type="button" class="btn btn-outline-secondary time-picker-option js-time-picker-option" data-time-value="${option.value}">` +
                    `${option.label}</button>`
                );
            })
            .join('');
    }

    function updateFieldLabel(fieldEl, value, explicitLabel) {
        const labelEl = getFieldLabel(fieldEl);
        if (!labelEl) return;

        if (!value) {
            labelEl.textContent = emptyLabel;
            labelEl.classList.add('app-muted');
            return;
        }

        labelEl.textContent = explicitLabel || value;
        labelEl.classList.remove('app-muted');
    }

    function highlightSelectedOption(modalEl, value) {
        if (!modalEl) return;

        modalEl.querySelectorAll('.js-time-picker-option').forEach(function (optionEl) {
            const isSelected = value && optionEl.dataset.timeValue === value;
            optionEl.classList.toggle('active', Boolean(isSelected));
            optionEl.classList.toggle('btn-primary', Boolean(isSelected));
            optionEl.classList.toggle('btn-outline-secondary', !isSelected);
        });
    }

    function applyTimeValue(fieldEl, value, labelText) {
        const inputEl = getFieldInput(fieldEl);
        if (!inputEl || inputEl.disabled) return;

        const previousValue = inputEl.value || '';
        const nextValue = value || '';

        updateFieldLabel(fieldEl, nextValue, labelText);
        if (previousValue === nextValue) return;

        inputEl.value = nextValue;
        inputEl.dispatchEvent(new Event('change', { bubbles: true }));
    }

    document.addEventListener('click', function (event) {
        const triggerEl = event.target.closest('.js-time-picker-trigger');
        if (!triggerEl) return;
        if (triggerEl.disabled) return;

        const fieldEl = triggerEl.closest('[data-time-picker-field]');
        const inputEl = getFieldInput(fieldEl);
        if (!fieldEl || !inputEl || inputEl.disabled) return;

        const modalEl = getModalElement();
        const bootstrapModal = getBootstrapModal(modalEl);
        if (!modalEl || !bootstrapModal) return;

        activeField = fieldEl;
        renderOptions(modalEl, resolveRange(fieldEl, modalEl));
        highlightSelectedOption(modalEl, inputEl.value || '');
        bootstrapModal.show();
    });

    document.addEventListener('click', function (event) {
        const optionEl = event.target.closest('.js-time-picker-option');
        if (!optionEl) return;
        if (!activeField) return;

        const modalEl = getModalElement();
        const bootstrapModal = getBootstrapModal(modalEl);
        const value = optionEl.dataset.timeValue || '';
        const labelText = optionEl.textContent ? optionEl.textContent.trim() : value;

        applyTimeValue(activeField, value, labelText);
        highlightSelectedOption(modalEl, value);
        if (bootstrapModal) bootstrapModal.hide();
    });

    document.addEventListener('click', function (event) {
        const clearButton = event.target.closest('.js-time-picker-clear');
        if (!clearButton) return;
        if (!activeField) return;

        const modalEl = getModalElement();
        const bootstrapModal = getBootstrapModal(modalEl);

        applyTimeValue(activeField, '', emptyLabel);
        highlightSelectedOption(modalEl, '');
        if (bootstrapModal) bootstrapModal.hide();
    });

    document.addEventListener('hidden.bs.modal', function (event) {
        const modalEl = event.target;
        if (!(modalEl instanceof HTMLElement)) return;
        if (modalEl.id !== modalId) return;

        activeField = null;
    });

    // Ensure labels stay in sync when rows are refreshed by AutoRefresh/HTMX.
    document.addEventListener('turbolinks:load', function () {
        document.querySelectorAll('[data-time-picker-field]').forEach(function (fieldEl) {
            const inputEl = getFieldInput(fieldEl);
            if (!inputEl) return;
            const modalEl = getModalElement();
            const selectedOption = findOptionByValue(modalEl, inputEl.value || '');
            const selectedLabel = selectedOption ? selectedOption.textContent.trim() : displayLabelFromValue(inputEl.value);
            updateFieldLabel(fieldEl, inputEl.value || '', selectedLabel);
        });
    });

})();

// Toggle break-time controls based on the "Had break" checkbox.
(function enableBreakTimeToggle() {
    if (typeof window === 'undefined') return;

    function syncBreakToggle(checkboxEl) {
        const targetSelector = checkboxEl.dataset.breakTarget;
        if (!targetSelector) return;

        const targetEl = document.querySelector(targetSelector);
        if (!targetEl) return;

        const isEnabled = checkboxEl.checked;
        targetEl.hidden = !isEnabled;
        targetEl.querySelectorAll('.js-time-picker-input, .js-time-picker-trigger').forEach(function (element) {
            element.disabled = !isEnabled;
        });
    }

    document.addEventListener('change', function (event) {
        const checkboxEl = event.target.closest('[data-break-toggle="true"]');
        if (!checkboxEl) return;
        syncBreakToggle(checkboxEl);
    });

    document.addEventListener('turbolinks:load', function () {
        document.querySelectorAll('[data-break-toggle="true"]').forEach(function (checkboxEl) {
            syncBreakToggle(checkboxEl);
        });
    });
})();
