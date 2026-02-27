module Web.View.RosterWeeks.Show where

import Data.Time.Calendar (Day)
import Web.View.Prelude

data ShowView = ShowView
    { rosterWeek    :: Maybe RosterWeek
    , rosterDays    :: [RosterDay]
    , weekOffset    :: Int
    , weekStartDate :: Day
    , weekEndDate   :: Day
    }

instance View ShowView where
    html ShowView { .. } = [hsx|
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href={DashboardAction}>Dashboard</a></li>
                <li class="breadcrumb-item active">Roster Week {weekOffset}</li>
            </ol>
        </nav>

        <div class="d-flex justify-content-between align-items-center mb-4">
            <h1>Roster: {tshow weekStartDate} to {tshow weekEndDate}</h1>
            <div class="d-flex gap-2 align-items-center">
                <a href={ShowRosterWeekAction (weekOffset - 1)} class="btn btn-outline-secondary">&larr; Prev Week</a>
                <a href={ShowRosterWeekAction (weekOffset + 1)} class="btn btn-outline-secondary">Next Week &rarr;</a>
            </div>
        </div>

        {renderRosterContent rosterWeek rosterDays weekOffset}
    |]

renderRosterContent :: (?context :: ControllerContext) => Maybe RosterWeek -> [RosterDay] -> Int -> Html
renderRosterContent Nothing _ weekOffset = [hsx|
    <div class="alert alert-info d-flex justify-content-between align-items-center">
        <div>
            <strong>No roster exists for this week yet.</strong>
            <p class="mb-0 text-muted">This week is currently empty. You can create a draft to start assigning staff.</p>
        </div>

        {when currentUserIsManager (renderCreateForm weekOffset)}
    </div>
|]

renderRosterContent (Just rosterWeek) rosterDays _ = [hsx|
    <div class="card mb-4">
        <div class="card-header d-flex justify-content-between align-items-center">
            <span>
                Status: {renderStatusBadge rosterWeek.isLive}
            </span>
            {when (not rosterWeek.isLive && currentUserIsManager) (renderPublishForm rosterWeek)}
        </div>
        <div class="card-body">
            <ul>
                {forEach rosterDays renderRosterDay}
            </ul>
        </div>
    </div>
|]

renderStatusBadge :: Bool -> Html
renderStatusBadge isLive =
    if isLive
        then [hsx|<span class="badge bg-success">Live / Published</span>|]
        else [hsx|<span class="badge bg-warning text-dark">Draft</span>|]

renderCreateForm :: Int -> Html
renderCreateForm weekOffset = [hsx|
    <form method="POST" action={CreateRosterWeekAction weekOffset}>
        <button type="submit" class="btn btn-primary">Create Draft Roster</button>
    </form>
|]

renderPublishForm :: RosterWeek -> Html
renderPublishForm rosterWeek = [hsx|
    <form method="POST" action={PublishRosterWeekAction rosterWeek.id} class="d-inline">
        <button type="submit" class="btn btn-sm btn-success">Publish Week</button>
    </form>
|]

renderRosterDay :: RosterDay -> Html
renderRosterDay rosterDay = [hsx|
    <li>Day Offset {rosterDay.dayOffset}</li>
|]
