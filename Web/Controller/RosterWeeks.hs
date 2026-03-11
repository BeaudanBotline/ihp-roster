module Web.Controller.RosterWeeks where

import Application.Helper.Conflict
import Application.Helper.Controller
import Application.Helper.LiveUpdate
import Application.Helper.View (linkedActiveStaffForRosterPanel)
import Data.Coerce (coerce)
import Data.List (find, nub, sortBy)
import Data.Maybe (catMaybes, mapMaybe)
import Data.Ord (comparing)
import qualified Data.Text as Text
import Data.Time (diffDays, getCurrentTime, utctDay)
import qualified Data.Time.Calendar as Calendar
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Data.Time.LocalTime (TimeOfDay)
import qualified Data.UUID as UUID
import Web.Controller.Prelude
import Web.View.RosterWeeks.Show (RosterStaffPanelEntry (..), ShowView (..),
                                  lastRowIndexForRows,
                                  renderRosterContentFragment,
                                  renderRosterContentFragmentOob,
                                  renderRosterStaffPanelFragment,
                                  renderRosterStaffPanelFragmentOob,
                                  renderRosterWeekShell, renderRowOob,
                                  rosterContentFragmentId, rosterRowDomIdText,
                                  rosterStaffPanelFragmentId, rowsForDay)

instance Controller RosterWeeksController where
    beforeAction = do
        ensureIsUser
        ensureCurrentVenue
        ensureProfileCompleted

    action RosterWeeksAction = do
        -- Redirect to the current week's offset based on today's date
        now <- liftIO getCurrentTime
        venueConfig <- fetchVenueConfig

        let today = utctDay now
        let epoch = venueConfig.weekOffsetEpoch
        let daysSinceEpoch = diffDays today epoch
        let currentWeekOffset = fromIntegral (daysSinceEpoch `div` 7)
        let currentWeekAction = ShowRosterWeekAction { weekOffset = currentWeekOffset }

        if isHtmxRequest
            then do
                setHtmxPushUrl (pathTo currentWeekAction)
                renderRosterWeekPage currentWeekOffset
            else redirectTo currentWeekAction

    action ShowRosterWeekAction { weekOffset } = autoRefresh do
        renderRosterWeekPage weekOffset

    action ShowRosterWeekContentFragmentAction { weekOffset } = do
        respondWithRosterContent weekOffset

    action ShowRosterWeekStaffPanelFragmentAction { weekOffset } = do
        panelStaff <- fetchVisibleRosterStaffPanelEntries weekOffset
        respondHtml $
            maybe mempty (renderRosterStaffPanelFragment weekOffset) panelStaff

    action ShowRosterWeekRowFragmentAction { weekOffset, rosterDayId, rowIndex } = do
        rowHtml <- fetchVisibleRosterRowFragment weekOffset rosterDayId rowIndex
        respondHtml (fromMaybe mempty rowHtml)

    action CreateRosterWeekAction { weekOffset } = do
        ensureManagerRole

        -- Make sure it doesn't already exist
        existing <- query @RosterWeek
            |> filterWhere (#venueId, unpackId currentVenueId)
            |> filterWhere (#weekOffset, weekOffset)
            |> fetchOneOrNothing
        case existing of
            Just week -> do
                redirectTo ShowRosterWeekAction { weekOffset = week.weekOffset }
            Nothing -> do
                slotNames <- query @SlotName
                    |> filterWhere (#venueId, unpackId currentVenueId)
                    |> filterWhere (#isActive, True)
                    |> fetch
                let orderedSlotNames = sortBy (comparing (slotNameOrder . (.name))) slotNames

                -- Create the roster week
                rosterWeek <- newRecord @RosterWeek
                    |> set #venueId (unpackId currentVenueId)
                    |> set #weekOffset weekOffset
                    |> set #isLive False
                    |> createRecord

                -- Create 7 roster days for the week with 5 default rows per day.
                forM_ [0 .. 6] \dayOffset -> do
                    rosterDay <- newRecord @RosterDay
                        |> set #rosterWeekId (coerce (get #id rosterWeek))
                        |> set #dayOffset dayOffset
                        |> createRecord

                    forM_ [0 .. 4] \rowIndex ->
                        forM_ orderedSlotNames \slotName -> do
                            newRecord @RosterSlot
                                |> set #rosterDayId (coerce (get #id rosterDay))
                                |> set #slotNameId (coerce (get #id slotName))
                                |> set #rowIndex rowIndex
                                |> createRecord

                setSuccessMessage "Roster week created successfully"
                redirectTo ShowRosterWeekAction { weekOffset }

    action CopyRosterWeekAction { sourceWeekOffset, targetWeekOffset } = do
        ensureManagerRole

        -- Make sure target doesn't already exist
        existingTarget <- query @RosterWeek
            |> filterWhere (#venueId, unpackId currentVenueId)
            |> filterWhere (#weekOffset, targetWeekOffset)
            |> fetchOneOrNothing
        case existingTarget of
            Just week -> do
                setErrorMessage "Target week already exists."
                redirectTo ShowRosterWeekAction { weekOffset = targetWeekOffset }
            Nothing -> do
                sourceWeekOrNothing <- query @RosterWeek
                    |> filterWhere (#venueId, unpackId currentVenueId)
                    |> filterWhere (#weekOffset, sourceWeekOffset)
                    |> fetchOneOrNothing
                case sourceWeekOrNothing of
                    Nothing -> do
                        setErrorMessage "Source week not found. Cannot copy."
                        redirectTo ShowRosterWeekAction { weekOffset = targetWeekOffset }
                    Just sourceWeek -> do
                        -- Create the target roster week
                        targetWeek <- newRecord @RosterWeek
                            |> set #venueId (unpackId currentVenueId)
                            |> set #weekOffset targetWeekOffset
                            |> set #isLive False
                            |> createRecord

                        sourceDays <- query @RosterDay |> filterWhere (#rosterWeekId, coerce (get #id sourceWeek)) |> fetch

                        -- Create 7 roster days for the week
                        forM_ [0 .. 6] \dayOffset -> do
                            targetDay <- newRecord @RosterDay
                                |> set #rosterWeekId (coerce (get #id targetWeek))
                                |> set #dayOffset dayOffset
                                |> createRecord

                            -- Find corresponding source day and copy slots
                            let maybeSourceDay = find (\d -> d.dayOffset == dayOffset) sourceDays
                            case maybeSourceDay of
                                Just sourceDay -> do
                                    sourceSlots <- query @RosterSlot |> filterWhere (#rosterDayId, coerce (get #id sourceDay)) |> fetch
                                    forM_ sourceSlots \slot -> do
                                        newRecord @RosterSlot
                                            |> set #rosterDayId (coerce (get #id targetDay))
                                            |> set #staffId slot.staffId
                                            |> set #slotNameId slot.slotNameId
                                            |> set #rowIndex slot.rowIndex
                                            |> set #startTime slot.startTime
                                            |> set #durationMinutes slot.durationMinutes
                                            |> set #note slot.note
                                            |> createRecord
                                        pure ()
                                Nothing -> pure ()

                        setSuccessMessage "Roster week copied successfully."
                        redirectTo ShowRosterWeekAction { weekOffset = targetWeekOffset }

    action PublishRosterWeekAction { rosterWeekId } = do
        ensureManagerRole
        rosterWeek <- fetch rosterWeekId
        ensureRecordInCurrentVenue rosterWeek.venueId
        rosterWeek
            |> set #isLive True
            |> updateRecord

        broadcastRosterWeekInvalidation
            rosterWeek.weekOffset
            [buildRosterContentFragmentRef rosterWeek.weekOffset]
        setSuccessMessage "Roster week published successfully"
        redirectTo ShowRosterWeekAction { weekOffset = rosterWeek.weekOffset }

    action AddRosterRowAction { rosterDayId } = do
        ensureManagerRole

        rosterDay <- fetch rosterDayId
        let rosterWeekId = (coerce rosterDay.rosterWeekId :: Id RosterWeek)
        rosterWeek <- fetch rosterWeekId
        ensureRecordInCurrentVenue rosterWeek.venueId

        -- Find the current max row index for this day
        existingSlots <- query @RosterSlot |> filterWhere (#rosterDayId, coerce rosterDayId) |> fetch
        let nextRowIndex = if null existingSlots then 0 else maximum (map (.rowIndex) existingSlots) + 1

        -- Get slot names for Early, Mid, Late
        slotNames <- query @SlotName
            |> filterWhere (#venueId, unpackId currentVenueId)
            |> filterWhere (#isActive, True)
            |> fetch
        let orderedSlotNames = sortBy (comparing (slotNameOrder . (.name))) slotNames

        -- Create a slot for each slot name (column)
        forM_ orderedSlotNames \slotName -> do
            newRecord @RosterSlot
                |> set #rosterDayId (coerce rosterDayId)
                |> set #slotNameId (coerce (get #id slotName))
                |> set #rowIndex nextRowIndex
                |> createRecord

        broadcastRosterWeekInvalidation
            rosterWeek.weekOffset
            [ buildRosterContentFragmentRef rosterWeek.weekOffset
            , buildRosterStaffPanelFragmentRef rosterWeek.weekOffset
            ]
        respondWithRosterContent rosterWeek.weekOffset

    action RemoveRosterRowAction { rosterDayId } = do
        ensureManagerRole

        rosterDay <- fetch rosterDayId
        let rosterWeekId = (coerce rosterDay.rosterWeekId :: Id RosterWeek)
        rosterWeek <- fetch rosterWeekId
        ensureRecordInCurrentVenue rosterWeek.venueId

        existingSlots <- query @RosterSlot
            |> filterWhere (#rosterDayId, coerce rosterDayId)
            |> fetch

        let maybeLastRowIndex =
                existingSlots
                    |> map (.rowIndex)
                    |> sort
                    |> last

        slotsToDelete <-
            case maybeLastRowIndex of
                Nothing -> pure []
                Just lastRowIndex ->
                    query @RosterSlot
                        |> filterWhere (#rosterDayId, coerce rosterDayId)
                        |> filterWhere (#rowIndex, lastRowIndex)
                        |> fetch

        deleteRecords slotsToDelete

        broadcastRosterWeekInvalidation
            rosterWeek.weekOffset
            [ buildRosterContentFragmentRef rosterWeek.weekOffset
            , buildRosterStaffPanelFragmentRef rosterWeek.weekOffset
            ]
        respondWithRosterContent rosterWeek.weekOffset

    action UpdateRosterSlotAction { rosterSlotId } = do
        ensureManagerRole

        rosterSlot <- fetch rosterSlotId
        let previousStaffId = rosterSlot.staffId
        let rosterDayId = (coerce rosterSlot.rosterDayId :: Id RosterDay)
        rosterDay <- fetch rosterDayId
        let rosterWeekId = (coerce rosterDay.rosterWeekId :: Id RosterWeek)
        rosterWeek <- fetch rosterWeekId
        ensureRecordInCurrentVenue rosterWeek.venueId

        let maybeStaffParam = paramOrNothing @Text "staffId"
        let maybeStartTimeParam = paramOrNothing @Text "startTime"
        let maybeNoteParam = paramOrNothing @Text "note"

        let updatedSlot =
                rosterSlot
                    |> applyOptionalField #staffId (parseOptionalStaffId maybeStaffParam) maybeStaffParam
                    |> applyOptionalField #startTime (parseOptionalTime maybeStartTimeParam) maybeStartTimeParam
                    |> applyOptionalField #note (normalizeOptionalText maybeNoteParam) maybeNoteParam

        ensureOptionalStaffInCurrentVenue updatedSlot.staffId
        _ <- updatedSlot |> updateRecord

        relatedSlots <- fetchRelatedSlotsForStaffIds (catMaybes [previousStaffId, updatedSlot.staffId])
        let impactedRowKeys = impactedRowKeysForSlotUpdate previousStaffId updatedSlot relatedSlots
        let shouldRefreshStaffPanel = previousStaffId /= updatedSlot.staffId
        broadcastRosterWeekInvalidation
            rosterWeek.weekOffset
            ( buildRosterRowFragmentRefs rosterWeek.weekOffset impactedRowKeys
                <> [buildRosterStaffPanelFragmentRef rosterWeek.weekOffset | shouldRefreshStaffPanel]
            )
        respondWithRosterPatches rosterWeek.weekOffset impactedRowKeys shouldRefreshStaffPanel

slotNameOrder :: Text -> Int
slotNameOrder slotName =
    case Text.toLower slotName of
        "early" -> 0
        "mid"   -> 1
        "late"  -> 2
        _       -> 3

parseOptionalStaffId :: Maybe Text -> Maybe UUID.UUID
parseOptionalStaffId value = UUID.fromText =<< normalizeOptionalText value

parseOptionalTime :: Maybe Text -> Maybe TimeOfDay
parseOptionalTime value =
    case normalizeOptionalText value of
        Nothing -> Nothing
        Just valueText -> parseTimeM True defaultTimeLocale "%H:%M" (cs valueText)

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText = \case
    Nothing -> Nothing
    Just value ->
        let trimmed = Text.strip value
         in if Text.null trimmed then Nothing else Just trimmed

buildSlotConflicts :: (?modelContext :: ModelContext) => Int -> Calendar.Day -> [RosterDay] -> [RosterSlot] -> [Staff] -> IO [(Id RosterSlot, [RosterConflict])]
buildSlotConflicts lateToEarlyMinStartGapMinutes weekStartDate rosterDays allSlots staffMembers = do
    let assignedStaffIds = nub $ mapMaybe (.staffId) allSlots
    if null assignedStaffIds
        then pure []
        else do
            leaveRequests <- query @LeaveRequest
                |> filterWhereIn (#staffId, assignedStaffIds)
                |> fetch

            availabilities <- query @StaffAvailability
                |> filterWhereIn (#staffId, assignedStaffIds)
                |> fetch

            let dayById = map (\day -> (coerce (get #id day), day)) rosterDays
            let conflictsBySlot = mapMaybe (conflictsForSlot dayById leaveRequests availabilities) allSlots
            pure conflictsBySlot
    where
        conflictsForSlot dayById leaveRequests availabilities slot = do
            staffUuid <- slot.staffId
            day <- lookup slot.rosterDayId dayById
            let weekSlotsForStaff = filter (\candidate -> candidate.staffId == Just staffUuid) allSlots
            let daySlotsForStaff = filter (\candidate -> candidate.rosterDayId == slot.rosterDayId && candidate.staffId == Just staffUuid) allSlots
            let staffIdealShifts = (.idealShiftsPerWeek) =<< find (\staff -> coerce (get #id staff) == staffUuid) staffMembers
            let leaveRequestsForStaff = filter (\leaveRequest -> leaveRequest.staffId == staffUuid) leaveRequests
            let availabilitiesForStaff = filter (\availability -> availability.staffId == staffUuid) availabilities
            let rosterDayDate = Calendar.addDays (toInteger day.dayOffset) weekStartDate
            let conflicts = evaluateConflicts ConflictContext
                    { slot
                    , weekSlots = weekSlotsForStaff
                    , daySlots = daySlotsForStaff
                    , weekRosterDays = rosterDays
                    , leaveRequests = leaveRequestsForStaff
                    , availabilities = availabilitiesForStaff
                    , rosterDayDate
                    , lateToEarlyMinStartGapMinutes
                    , staffIdealShifts
                    }
            if null conflicts
                then Nothing
                else Just (get #id slot, conflicts)

respondWithRosterContent :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> IO ()
respondWithRosterContent weekOffset = do
    rosterData <- fetchVisibleRosterRenderData weekOffset
    case rosterData of
        Nothing -> respondHtml [hsx|<div id="roster-content"></div>|]
        Just RosterRenderData { rosterWeek, rosterDays, weekStartDate, staffMembers, panelStaff, orderedSlotNames, allSlots, slotConflicts } ->
            respondHtml $
                renderRosterContentFragment
                    (Just rosterWeek)
                    rosterDays
                    weekOffset
                    staffMembers
                    panelStaff
                    orderedSlotNames
                    weekStartDate
                    allSlots
                    slotConflicts

respondWithRosterContentOob :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> IO ()
respondWithRosterContentOob weekOffset = do
    rosterData <- fetchVisibleRosterRenderData weekOffset
    case rosterData of
        Nothing -> respondHtml [hsx|<div id="roster-content" hx-swap-oob="outerHTML"></div>|]
        Just RosterRenderData { rosterWeek, rosterDays, weekStartDate, staffMembers, panelStaff, orderedSlotNames, allSlots, slotConflicts } ->
            respondHtml $
                renderRosterContentFragmentOob
                    (Just rosterWeek)
                    rosterDays
                    weekOffset
                    staffMembers
                    panelStaff
                    orderedSlotNames
                    weekStartDate
                    allSlots
                    slotConflicts

respondWithRosterRows :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> [(UUID.UUID, Int)] -> IO ()
respondWithRosterRows weekOffset requestedRowKeys =
    respondWithRosterPatches weekOffset requestedRowKeys False

respondWithRosterPatches :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> [(UUID.UUID, Int)] -> Bool -> IO ()
respondWithRosterPatches weekOffset requestedRowKeys shouldRefreshStaffPanel = do
    rosterData <- fetchVisibleRosterRenderData weekOffset
    case rosterData of
        Nothing -> respondHtml [hsx||]
        Just RosterRenderData { rosterDays, weekStartDate, staffMembers, panelStaff, orderedSlotNames, allSlots, slotConflicts } -> do
            let uniqueRowKeys = nub requestedRowKeys
            let renderedRows = mapMaybe (renderRequestedRow rosterDays weekStartDate orderedSlotNames staffMembers allSlots slotConflicts) uniqueRowKeys
            let renderedStaffPanel = [renderRosterStaffPanelFragmentOob weekOffset panelStaff | shouldRefreshStaffPanel]
            respondHtml (mconcat (renderedRows <> renderedStaffPanel))

renderRosterWeekPage :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> IO ()
renderRosterWeekPage weekOffset = do
    venueConfig <- fetchVenueConfig
    let epoch = venueConfig.weekOffsetEpoch
    let weekStartDate = Calendar.addDays (toInteger (weekOffset * 7)) epoch
    let weekEndDate = Calendar.addDays 6 weekStartDate

    visibleRosterWeek <- fetchVisibleRosterWeek weekOffset

    case visibleRosterWeek of
        Just rosterWeek -> do
            rosterDays <- query @RosterDay
                |> filterWhere (#rosterWeekId, coerce (get #id rosterWeek))
                |> orderBy #dayOffset
                |> fetch

            allSlots <- query @RosterSlot
                |> filterWhereIn (#rosterDayId, map (coerce . (.id)) rosterDays)
                |> fetch

            staffMembers <- query @Staff
                |> filterWhere (#venueId, unpackId currentVenueId)
                |> filterWhere (#isActive, True)
                |> orderBy #lastName
                |> fetch

            panelStaff <- fetchRosterStaffPanelEntries staffMembers allSlots

            slotNames <- query @SlotName
                |> filterWhere (#venueId, unpackId currentVenueId)
                |> filterWhere (#isActive, True)
                |> fetch

            let orderedSlotNames = sortBy (comparing (slotNameOrder . (.name))) slotNames
            slotConflicts <- buildSlotConflicts venueConfig.lateToEarlyMinStartGapMinutes weekStartDate rosterDays allSlots staffMembers

            respondWithRosterWeekView
                ShowView
                    { rosterWeek = Just rosterWeek
                    , rosterDays
                    , weekOffset
                    , weekStartDate
                    , weekEndDate
                    , staffMembers
                    , panelStaff
                    , slotNames = orderedSlotNames
                    , allSlots
                    , slotConflicts
                    , liveUpdateScope = Just (RosterWeekScope { venueId = unpackId currentVenueId, weekOffset })
                    }
        Nothing ->
            respondWithRosterWeekView
                ShowView
                    { rosterWeek = Nothing
                    , rosterDays = []
                    , weekOffset
                    , weekStartDate
                    , weekEndDate
                    , staffMembers = []
                    , panelStaff = []
                    , slotNames = []
                    , allSlots = []
                    , slotConflicts = []
                    , liveUpdateScope = Nothing
                    }

respondWithRosterWeekView :: (?context :: ControllerContext) => ShowView -> IO ()
respondWithRosterWeekView showView =
    if isHtmxRequest
        then respondHtml (renderRosterWeekShell showView)
        else render showView

fetchRelatedSlotsForStaffIds :: (?modelContext :: ModelContext) => [UUID.UUID] -> IO [RosterSlot]
fetchRelatedSlotsForStaffIds staffIds =
    if null staffIds
        then pure []
        else query @RosterSlot
            |> filterWhereIn (#staffId, map Just (nub staffIds))
            |> fetch

data RosterRenderData = RosterRenderData
    { rosterWeek       :: RosterWeek
    , rosterDays       :: [RosterDay]
    , weekStartDate    :: Calendar.Day
    , staffMembers     :: [Staff]
    , panelStaff       :: [RosterStaffPanelEntry]
    , orderedSlotNames :: [SlotName]
    , allSlots         :: [RosterSlot]
    , slotConflicts    :: [(Id RosterSlot, [RosterConflict])]
    }

fetchRosterRenderData :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> IO (Maybe RosterRenderData)
fetchRosterRenderData weekOffset = do
    venueConfig <- fetchVenueConfig
    let epoch = venueConfig.weekOffsetEpoch
    let weekStartDate = Calendar.addDays (toInteger (weekOffset * 7)) epoch

    rosterWeekOrNothing <- query @RosterWeek
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> filterWhere (#weekOffset, weekOffset)
        |> fetchOneOrNothing

    case rosterWeekOrNothing of
        Nothing -> pure Nothing
        Just rosterWeek -> do
            rosterDays <- query @RosterDay
                |> filterWhere (#rosterWeekId, coerce (get #id rosterWeek))
                |> orderBy #dayOffset
                |> fetch

            allSlots <- query @RosterSlot
                |> filterWhereIn (#rosterDayId, map (coerce . (.id)) rosterDays)
                |> fetch

            staffMembers <- query @Staff
                |> filterWhere (#venueId, unpackId currentVenueId)
                |> filterWhere (#isActive, True)
                |> orderBy #lastName
                |> fetch

            panelStaff <- fetchRosterStaffPanelEntries staffMembers allSlots

            slotNames <- query @SlotName
                |> filterWhere (#venueId, unpackId currentVenueId)
                |> filterWhere (#isActive, True)
                |> fetch

            let orderedSlotNames = sortBy (comparing (slotNameOrder . (.name))) slotNames
            slotConflicts <- buildSlotConflicts venueConfig.lateToEarlyMinStartGapMinutes weekStartDate rosterDays allSlots staffMembers
            pure (Just RosterRenderData { rosterWeek, rosterDays, weekStartDate, staffMembers, panelStaff, orderedSlotNames, allSlots, slotConflicts })

fetchVisibleRosterRenderData :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> IO (Maybe RosterRenderData)
fetchVisibleRosterRenderData weekOffset = do
    visibleRosterWeek <- fetchVisibleRosterWeek weekOffset
    case visibleRosterWeek of
        Nothing -> pure Nothing
        Just _  -> fetchRosterRenderData weekOffset

fetchVisibleRosterWeek :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> IO (Maybe RosterWeek)
fetchVisibleRosterWeek weekOffset = do
    rosterWeekOrNothing <-
        query @RosterWeek
            |> filterWhere (#venueId, unpackId currentVenueId)
            |> filterWhere (#weekOffset, weekOffset)
            |> fetchOneOrNothing

    pure $
        case rosterWeekOrNothing of
            Just rosterWeek | rosterWeek.isLive || hasRole ManagerRole' -> Just rosterWeek
            _ -> Nothing

fetchVisibleRosterStaffPanelEntries :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Int -> IO (Maybe [RosterStaffPanelEntry])
fetchVisibleRosterStaffPanelEntries weekOffset = do
    rosterData <- fetchVisibleRosterRenderData weekOffset
    pure ((\RosterRenderData { panelStaff } -> panelStaff) <$> rosterData)

fetchVisibleRosterRowFragment weekOffset rosterDayId rowIndex = do
    rosterData <- fetchVisibleRosterRenderData weekOffset
    pure do
        RosterRenderData { rosterDays, weekStartDate, staffMembers, orderedSlotNames, allSlots, slotConflicts } <- rosterData
        renderRequestedRow rosterDays weekStartDate orderedSlotNames staffMembers allSlots slotConflicts (unpackId rosterDayId, rowIndex)

buildRosterWeekScope :: (?context :: ControllerContext) => Int -> LiveUpdateScope
buildRosterWeekScope weekOffset =
    RosterWeekScope
        { venueId = unpackId currentVenueId
        , weekOffset
        }

buildRosterContentFragmentRef :: (?context :: ControllerContext) => Int -> LiveFragmentRef
buildRosterContentFragmentRef weekOffset =
    LiveFragmentRef
        { fragmentKey = RosterContentFragment
        , targetId = rosterContentFragmentId
        , url = pathTo ShowRosterWeekContentFragmentAction { weekOffset }
        , deferUntilBlur = False
        }

buildRosterStaffPanelFragmentRef :: (?context :: ControllerContext) => Int -> LiveFragmentRef
buildRosterStaffPanelFragmentRef weekOffset =
    LiveFragmentRef
        { fragmentKey = RosterStaffPanelFragment
        , targetId = rosterStaffPanelFragmentId
        , url = pathTo ShowRosterWeekStaffPanelFragmentAction { weekOffset }
        , deferUntilBlur = False
        }

buildRosterRowFragmentRefs :: (?context :: ControllerContext) => Int -> [(UUID.UUID, Int)] -> [LiveFragmentRef]
buildRosterRowFragmentRefs weekOffset =
    map (uncurry (buildRosterRowFragmentRef weekOffset)) . nub

buildRosterRowFragmentRef :: (?context :: ControllerContext) => Int -> UUID.UUID -> Int -> LiveFragmentRef
buildRosterRowFragmentRef weekOffset rosterDayId rowIndex =
    LiveFragmentRef
        { fragmentKey = RosterRowFragment { rosterDayId, rowIndex }
        , targetId = rosterRowDomIdText (coerce rosterDayId) rowIndex
        , url = pathTo ShowRosterWeekRowFragmentAction { weekOffset, rosterDayId = coerce rosterDayId, rowIndex }
        , deferUntilBlur = True
        }

broadcastRosterWeekInvalidation ::
    (?context :: ControllerContext) =>
    Int ->
    [LiveFragmentRef] ->
    IO ()
broadcastRosterWeekInvalidation weekOffset fragments =
    unless (null fragments) do
        liftIO $
            broadcastLiveInvalidation
                (buildRosterWeekScope weekOffset)
                (cs <$> getHeader "X-Live-Update-Client-Id")
                fragments

fetchRosterStaffPanelEntries :: (?context :: ControllerContext, ?modelContext :: ModelContext) => [Staff] -> [RosterSlot] -> IO [RosterStaffPanelEntry]
fetchRosterStaffPanelEntries staffMembers allSlots = do
    let linkedStaff = linkedActiveStaffForRosterPanel staffMembers
    let linkedUserIds = mapMaybe (.userId) linkedStaff

    memberships <-
        if null linkedUserIds
            then pure []
            else query @VenueMembership
                |> filterWhere (#venueId, unpackId currentVenueId)
                |> filterWhereIn (#userId, linkedUserIds)
                |> filterWhere (#isActive, True)
                |> fetch

    pure (map (buildPanelEntry memberships) linkedStaff)
    where
        buildPanelEntry memberships staff =
            let assignedShiftCount = length (filter (\slot -> slot.staffId == Just (coerce (get #id staff))) allSlots)
                roleText = case staff.userId >>= \userId -> find (\membership -> membership.userId == userId) memberships of
                    Just membership -> inputValue membership.venueRole
                    Nothing         -> venueRoleToText WorkerRole
             in RosterStaffPanelEntry
                    { staff
                    , assignedShiftCount
                    , userRole = roleText
                    }

renderRequestedRow rosterDays weekStartDate orderedSlotNames staffMembers allSlots slotConflicts (rosterDayUuid, targetRowIndex) = do
    rosterDay <- find (\day -> coerce (get #id day) == rosterDayUuid) rosterDays
    let daySlots = filter (\slot -> slot.rosterDayId == rosterDayUuid) allSlots
    let dayRows = rowsForDay daySlots
    let rowCount = length dayRows
    let lastRowIndex = lastRowIndexForRows dayRows
    let indexedRows = zip [0 :: Int ..] dayRows
    (rowPosition, (_, rowSlots)) <- find (\(_, (rowIndex, _)) -> rowIndex == targetRowIndex) indexedRows
    let date = Calendar.addDays (toInteger (get #dayOffset rosterDay)) weekStartDate
    pure (renderRowOob orderedSlotNames staffMembers date rosterDay rowCount lastRowIndex slotConflicts (rowPosition, (targetRowIndex, rowSlots)))

impactedRowKeysForSlotUpdate :: Maybe UUID.UUID -> RosterSlot -> [RosterSlot] -> [(UUID.UUID, Int)]
impactedRowKeysForSlotUpdate previousStaffId updatedSlot relatedSlots =
    nub $
        (updatedSlot.rosterDayId, updatedSlot.rowIndex)
            : map (\slot -> (slot.rosterDayId, slot.rowIndex)) affectedSlots
    where
        impactedStaffIds = catMaybes [previousStaffId, updatedSlot.staffId]
        affectedSlots = filter (\slot -> slot.staffId `elem` map Just impactedStaffIds) relatedSlots

applyOptionalField :: forall field model value. (SetField field model value) => Proxy field -> value -> Maybe Text -> model -> model
applyOptionalField _ parsedValue rawParam model =
    case rawParam of
        Nothing -> model
        Just _  -> setField @field parsedValue model
