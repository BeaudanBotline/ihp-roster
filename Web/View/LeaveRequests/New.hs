module Web.View.LeaveRequests.New where

import Web.View.Prelude

newtype NewView = NewView
    { leaveRequest :: LeaveRequest
    }

instance View NewView where
    html NewView { .. } = [hsx|
        <h1>New Leave Request</h1>
        {renderLeaveRequestForm leaveRequest}
    |]

renderLeaveRequestForm :: LeaveRequest -> Html
renderLeaveRequestForm leaveRequest = [hsx|
    <form method="POST" action={CreateLeaveRequestAction} class="mt-3 app-form-width">
        <div class="mb-3">
            <label for="startDate" class="form-label">Start Date</label>
            <input
                id="startDate"
                name="startDate"
                type="date"
                class={classes [("form-control", True), ("is-invalid", leaveHasErrorFor leaveRequest "startDate")]}
                value={tshow leaveRequest.startDate}
                required="required"
            />
            {renderLeaveFieldError leaveRequest "startDate"}
        </div>

        <div class="mb-3">
            <label for="endDate" class="form-label">End Date</label>
            <input
                id="endDate"
                name="endDate"
                type="date"
                class={classes [("form-control", True), ("is-invalid", leaveHasErrorFor leaveRequest "endDate")]}
                value={tshow leaveRequest.endDate}
                required="required"
            />
            <div class="form-text">End date must be the same as or after start date.</div>
            {renderLeaveFieldError leaveRequest "endDate"}
        </div>

        <div class="mb-3">
            <label for="notes" class="form-label">Notes</label>
            <textarea
                id="notes"
                name="notes"
                rows="3"
                class={classes [("form-control", True), ("is-invalid", leaveHasErrorFor leaveRequest "notes")]}
            >{fromMaybe "" leaveRequest.notes}</textarea>
            {renderLeaveFieldError leaveRequest "notes"}
        </div>

        <button type="submit" class="btn btn-primary">Submit Request</button>
        <a href={LeaveRequestsAction} class="btn btn-outline-secondary ms-2">Cancel</a>
    </form>
|]

renderLeaveFieldError :: LeaveRequest -> Text -> Html
renderLeaveFieldError leaveRequest fieldName =
    case lookup fieldName leaveRequest.meta.annotations of
        Just (TextViolation msg) -> [hsx|<div class="invalid-feedback d-block">{msg}</div>|]
        Just (HtmlViolation msg) -> [hsx|<div class="invalid-feedback d-block">{msg}</div>|]
        Nothing -> mempty

leaveHasErrorFor :: LeaveRequest -> Text -> Bool
leaveHasErrorFor leaveRequest fieldName = isJust (lookup fieldName leaveRequest.meta.annotations)
