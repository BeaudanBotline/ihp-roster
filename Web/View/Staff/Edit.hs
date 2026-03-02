module Web.View.Staff.Edit where

import Web.View.Prelude

data EditView = EditView
    { staff      :: Staff
    , weekOffset :: Int
    }

instance View EditView where
    html EditView { .. } =
        renderStaffEditPageModal
            weekOffset
            staffEditFormId
            (renderForm PageOverlayForm staff weekOffset (UpdateStaffAction (get #id staff)))

staffEditFormId :: Text
staffEditFormId = "staff-edit-form"

renderStaffEditModalFragment :: Staff -> Int -> Html
renderStaffEditModalFragment staff weekOffset =
    renderStaffEditDialog
        staffEditFormId
        (renderForm HtmxOverlayForm staff weekOffset (UpdateStaffAction (get #id staff)))

renderForm :: OverlayFormMode -> Staff -> Int -> StaffController -> Html
renderForm formMode staff weekOffset action =
    case formMode of
        HtmxOverlayForm -> [hsx|
            <form id={staffEditFormId}
                  method="POST"
                  action={action}
                  class="mt-3"
                  hx-post={action}
                  hx-target={"#" <> dialogOverlayMountId}
                  hx-swap="innerHTML"
                  hx-push-url="false">
                {renderFormFields staff weekOffset}
            </form>
        |]
        PageOverlayForm -> [hsx|
            <form id={staffEditFormId}
                  method="POST"
                  action={action}
                  class="mt-3">
                {renderFormFields staff weekOffset}
            </form>
        |]

renderFormFields :: Staff -> Int -> Html
renderFormFields staff weekOffset = [hsx|
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
