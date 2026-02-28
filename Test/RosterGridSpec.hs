module Test.RosterGridSpec where

import Generated.Types
import IHP.ControllerPrelude (newRecord)
import IHP.Prelude
import Test.Hspec
import Web.View.RosterWeeks.Show (rowsForDay)

tests :: Spec
tests = describe "Roster grid row grouping" do
    it "returns a single placeholder row when a day has no slots" do
        rowsForDay [] `shouldBe` [(-1, [])]

    it "groups slots by row_index in ascending order" do
        let mkSlot rowIndex =
                (newRecord @RosterSlot)
                    |> set #rowIndex rowIndex
        let rows = rowsForDay [mkSlot 2, mkSlot 0, mkSlot 2, mkSlot 1]
        map fst rows `shouldBe` [0, 1, 2]
        map (length . snd) rows `shouldBe` [1, 1, 2]
