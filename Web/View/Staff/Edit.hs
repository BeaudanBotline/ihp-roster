module Web.View.Staff.Edit where

import Web.View.Prelude

data EditView = EditView
    { staff      :: Staff
    , weekOffset :: Int
    }

instance View EditView where
    html EditView { .. } = renderStaffEditModalFragment staff weekOffset

renderStaffEditModalFragment :: Staff -> Int -> Html
renderStaffEditModalFragment staff weekOffset =
    renderStaffEditModal
        "Edit Staff Member"
        weekOffset
        (renderForm staff weekOffset (UpdateStaffAction (get #id staff)))

renderForm :: Staff -> Int -> StaffController -> Html
renderForm staff weekOffset action = [hsx|
    <form method="POST"
          action={action}
          class="mt-3"
          hx-post={action}
          hx-target={"#" <> htmxModalMountId}
          hx-swap="innerHTML"
          hx-push-url="false">
        <input type="hidden" name="weekOffset" value={tshow weekOffset} />
        <div class="mb-3">
            <label for="firstName" class="form-label">First Name</label>
            <input
                id="firstName"
                name="firstName"
                type="text"
                class={inputClass staff "firstName"}
                value={staff.firstName}
                required="required"
                autofocus="autofocus"
            />
            {renderStaffFieldError staff "firstName"}
        </div>
        <div class="mb-3">
            <label for="lastName" class="form-label">Last Name</label>
            <input
                id="lastName"
                name="lastName"
                type="text"
                class={inputClass staff "lastName"}
                value={staff.lastName}
                required="required"
            />
            {renderStaffFieldError staff "lastName"}
        </div>
        <div class="mb-3">
            <label for="idealShiftsPerWeek" class="form-label">Ideal Shifts Per Week</label>
            <input
                id="idealShiftsPerWeek"
                name="idealShiftsPerWeek"
                type="number"
                min="0"
                max="14"
                class={inputClass staff "idealShiftsPerWeek"}
                value={maybe "" show staff.idealShiftsPerWeek}
                placeholder="Optional"
            />
            {renderStaffFieldError staff "idealShiftsPerWeek"}
        </div>
        <div class="mb-3">
            <label for="isActive" class="form-label">Status</label>
            <select name="isActive" id="isActive" class={selectClass staff "isActive"}>
                <option value="on" selected={staff.isActive}>Active</option>
                <option value="" selected={not staff.isActive}>Inactive</option>
            </select>
            {renderStaffFieldError staff "isActive"}
        </div>
        <button type="submit" class="btn btn-primary">Save</button>
        <a href={ShowRosterWeekAction weekOffset} class="btn btn-outline-secondary ms-2" data-htmx-modal-close="true">Cancel</a>
    </form>
|]

inputClass :: Staff -> Text -> Text
inputClass staff fieldName =
    classes [("form-control", True), ("is-invalid", hasStaffErrorFor staff fieldName)]

selectClass :: Staff -> Text -> Text
selectClass staff fieldName =
    classes [("form-select", True), ("is-invalid", hasStaffErrorFor staff fieldName)]

renderStaffFieldError :: Staff -> Text -> Html
renderStaffFieldError staff fieldName =
    case lookup fieldName staff.meta.annotations of
        Just (TextViolation messageText) -> [hsx|<div class="invalid-feedback d-block">{messageText}</div>|]
        Just (HtmlViolation messageHtml) -> [hsx|<div class="invalid-feedback d-block">{messageHtml}</div>|]
        Nothing -> mempty

hasStaffErrorFor :: Staff -> Text -> Bool
hasStaffErrorFor staff fieldName = isJust (lookup fieldName staff.meta.annotations)
