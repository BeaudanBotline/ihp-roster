module Test.PaySpec where

import Application.Helper.Pay
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import IHP.Prelude
import Test.Hspec

tests :: Spec
tests = describe "Pay helper orchestration" do
    it "decodes single-entry pay payloads" do
        let payload = "{\"entryId\":\"11111111-1111-1111-1111-111111111111\",\"segments\":[{\"segment\":\"ordinary\",\"minutes\":480,\"dayRuleMultiplier\":1.25,\"weekendMultiplier\":1.5,\"multiplier\":1.875,\"baseRate\":0,\"amount\":0}],\"totals\":{\"paidMinutes\":480,\"totalAmount\":0}}"
        case decodeTimesheetPayResult payload of
            Left err -> expectationFailure ("Expected decode success, got: " <> Text.unpack err)
            Right result -> do
                result.entryId `shouldBe` "11111111-1111-1111-1111-111111111111"
                result.totals.paidMinutes `shouldBe` 480
                fmap (.segment) result.segments `shouldBe` ["ordinary"]

    it "builds summary flags for weekend and stacked multipliers" do
        let result = TimesheetPayResult
                { entryId = "11111111-1111-1111-1111-111111111111"
                , segments =
                    [ PaySegment
                        { segment = "evening"
                        , minutes = 120
                        , multiplier = 1.875
                        , dayRuleMultiplier = Just 1.25
                        , weekendMultiplier = Just 1.5
                        }
                    ]
                , totals = PayTotals { paidMinutes = 120, totalAmount = 0 }
                }
            summary = buildTimesheetPaySummary result
        summary.paidMinutes `shouldBe` 120
        summary.segmentCount `shouldBe` 1
        summary.weekendApplied `shouldBe` True
        summary.hasStackedMultiplier `shouldBe` True
        summary.totalAmount `shouldBe` 0

    it "decodes range payload arrays and indexes summaries by entry id" do
        let payload = "[{\"entryId\":\"a\",\"segments\":[{\"segment\":\"ordinary\",\"minutes\":60,\"dayRuleMultiplier\":1.0,\"weekendMultiplier\":1.0,\"multiplier\":1.0,\"baseRate\":0,\"amount\":0}],\"totals\":{\"paidMinutes\":60,\"totalAmount\":0}},{\"entryId\":\"b\",\"segments\":[{\"segment\":\"evening\",\"minutes\":30,\"dayRuleMultiplier\":1.0,\"weekendMultiplier\":1.5,\"multiplier\":1.5,\"baseRate\":0,\"amount\":0}],\"totals\":{\"paidMinutes\":30,\"totalAmount\":0}}]"
        case decodeTimesheetPayResults payload of
            Left err -> expectationFailure ("Expected decode success, got: " <> Text.unpack err)
            Right results -> do
                length results `shouldBe` 2
                let summaries = buildTimesheetPaySummariesByEntryId results
                fmap (.weekendApplied) (Map.lookup "a" summaries) `shouldBe` Just False
                fmap (.weekendApplied) (Map.lookup "b" summaries) `shouldBe` Just True
