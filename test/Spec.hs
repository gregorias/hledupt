import           LedgerData (Currency (..), Posting (..), Value (..),
                             negateValue, postingToLedger, valueToLedger)
import           Test.Hspec (describe, hspec, it, shouldBe)
import           Test.HUnit (Test (..), assertEqual, runTestTT, (~:), (~=?))
import           Test.Mbank (mbankTests)

main :: IO ()
main = hspec ledgerDataTests

ledgerDataTests = do
  mbankTests
  describe "LedgerData tests" $ do
    describe "negateValue" $ do
      it "negates a value" $ do
        negateValue (Value 1 PLN) `shouldBe` Value (-1) PLN


    describe "valueToLedger" $ do
      it "produces a value string" $ do
        valueToLedger (Value 100 PLN) `shouldBe` "100 PLN"


    describe "postingToLedger" $ do
      it "produces a posting" $ do
        postingToLedger posting `shouldBe` expected
        where
          posting = Posting
            "A"
            (Value 100 PLN)
            (Value 200 PLN)
            (Value 0.25 CHF)
          expected :: String
          expected = "  A  100 PLN @ 0.25 CHF = 200 PLN"
