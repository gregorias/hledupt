{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Test.Hledger.Read.TestUtils (tests) where

import qualified Control.Lens as L
import Data.Time (fromGregorian)
import Hledger (
  Amount (aprice),
  AmountPrice (UnitPrice),
  missingamt,
  setFullPrecision,
 )
import Hledger.Data.Extra (
  makeCommodityAmount,
  makeCurrencyAmount,
 )
import Hledger.Data.Lens (tDescription, tStatus)
import Hledger.Data.Posting (
  balassert,
  nullposting,
  post,
 )
import Hledger.Data.Transaction (transaction)
import Hledger.Data.Types (
  MixedAmount (..),
  Posting (..),
  Status (..),
 )
import Hledger.Read.TestUtils (
  parseTransactionUnsafe,
  postingP,
  transactionP,
 )
import Hledupt.Data.Currency (Currency (..))
import Relude
import Test.Hspec (describe, it)
import qualified Test.Hspec as Hspec
import Test.Hspec.Expectations.Pretty (shouldBe)
import Text.Megaparsec (parseMaybe)

tests :: Hspec.SpecWith ()
tests = do
  describe "Test.Hledger.Read.TestUtils" $ do
    describe "postingP" $ do
      it "Parses a posting transaction" $ do
        let p :: String = "  Expenses:Other"
            expectedP = post "Expenses:Other" missingamt
        parseMaybe postingP p `shouldBe` Just expectedP
      it "Parses a posting transaction with spaces" $ do
        let p :: String = "  Assets:Bank With Spaces\n"
            expectedP = post "Assets:Bank With Spaces" missingamt
        parseMaybe postingP p `shouldBe` Just expectedP
      it "Parses a cleared posting" $ do
        let p :: String = "*  Expenses:Other"
            expectedP =
              (post "Expenses:Other" missingamt)
                { pstatus = Cleared
                }
        parseMaybe postingP p `shouldBe` Just expectedP

    describe "transactionParser" $ do
      it "Parses a moneyless transaction" $ do
        let tr =
              "2019/10/28 * Title\n\
              \  Assets:Bank With Spaces\n\
              \  Expenses:Other"
            expectedTrBase =
              transaction
                (fromGregorian 2019 10 28)
                [ post "Assets:Bank With Spaces" missingamt
                , post "Expenses:Other" missingamt
                ]
            expectedTr =
              expectedTrBase
                & L.set tDescription "Title"
                & L.set tStatus Cleared
        parseTransactionUnsafe tr `shouldBe` expectedTr
      it "Parses a proper transaction with amount" $ do
        let tr =
              "2019/10/28 * Title\n\
              \  Assets:Bank With Spaces  SPY -15\n\
              \  Expenses:Other"
            expectedTrBase =
              transaction
                (fromGregorian 2019 10 28)
                [ post
                    "Assets:Bank With Spaces"
                    (makeCommodityAmount "SPY" (-15))
                , post "Expenses:Other" missingamt
                ]
            expectedTr =
              expectedTrBase
                & L.set tDescription "Title"
                & L.set tStatus Cleared
        parseTransactionUnsafe tr `shouldBe` expectedTr
      it "Parses a proper transaction with spaceless amount" $ do
        let tr =
              "2019/10/28 Title\n\
              \  Bank  -15SPY"
            expectedTrBase =
              transaction
                (fromGregorian 2019 10 28)
                [ post
                    "Bank"
                    (makeCommodityAmount "SPY" (-15))
                ]
            expectedTr =
              expectedTrBase
                & L.set tDescription "Title"
        parseMaybe transactionP tr `shouldBe` Just expectedTr
      it "Parses a proper transaction with balance" $ do
        let tr =
              "2019/10/28 * Title\n\
              \  Assets:Bank  = SPY 123\n\
              \  Expenses:Other"
            expectedTrBase =
              transaction
                (fromGregorian 2019 10 28)
                [ (post "Assets:Bank" missingamt)
                    { pbalanceassertion =
                        balassert $ makeCommodityAmount "SPY" 123
                    }
                , post "Expenses:Other" missingamt
                ]
            expectedTr =
              expectedTrBase
                & L.set tDescription "Title"
                & L.set tStatus Cleared
        parseTransactionUnsafe tr `shouldBe` expectedTr
      it "Parses a proper transaction with amount & balance" $ do
        let tr =
              "2019/10/28 * Title\n\
              \  Assets:Bank  SPY 100 = SPY 123\n\
              \  Expenses:Other"
            expectedTrBase =
              transaction
                (fromGregorian 2019 10 28)
                [ nullposting
                    { paccount = "Assets:Bank"
                    , pbalanceassertion =
                        balassert $
                          makeCommodityAmount "SPY" 123
                    , pamount = Mixed [makeCommodityAmount "SPY" 100]
                    }
                , post "Expenses:Other" missingamt
                ]
            expectedTr =
              expectedTrBase
                & L.set tDescription "Title"
                & L.set tStatus Cleared
        parseTransactionUnsafe tr `shouldBe` expectedTr
      it "Parses a Forex posting with price information." $ do
        let posting = "  Assets:Bank  USD 100 @ CHF 0.9513\n"
            expectedPosting =
              post
                "Assets:Bank"
                ( (makeCurrencyAmount USD 100)
                    { aprice =
                        Just . UnitPrice $
                          makeCommodityAmount "CHF" 0.9513
                            & setFullPrecision
                    }
                )
        parseMaybe postingP posting `shouldBe` Just expectedPosting
