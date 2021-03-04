{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE TypeFamilies #-}

module Hledger.Read.TestUtils (
  postingParser,
  transactionParser,
  parseTransactionUnsafe,
) where

import qualified Control.Lens as L
import Control.Monad (liftM2)
import Control.Monad.Combinators (
  manyTill,
  someTill,
 )
import Data.Maybe (fromJust)
import Data.Text (pack, unpack)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Hledger (AmountPrice (TotalPrice, UnitPrice), missingamt, post, setFullPrecision)
import Hledger.Data.Amount (num)
import Hledger.Data.Extra (
  makeCommodityAmount,
  setCurrencyPrecision,
 )
import Hledger.Data.Lens (
  pBalanceAssertion,
  pStatus,
  tDescription,
  tStatus,
 )
import Hledger.Data.Posting (balassert)
import qualified Hledger.Data.Transaction as Tr
import Hledger.Data.Types (
  Amount (..),
  BalanceAssertion (..),
  Posting (..),
  Status (..),
  Transaction,
 )
import Hledupt.Data.MyDecimal (decimalP, defaultDecimalFormat)
import Relude
import Text.Megaparsec (
  MonadParsec (lookAhead),
  Token,
  anySingle,
  choice,
  single,
  try,
 )
import qualified Text.Megaparsec as MP
import Text.Megaparsec.Char (
  alphaNumChar,
  char,
  newline,
  printChar,
  spaceChar,
  string,
 )
import qualified Text.Megaparsec.Char as Char
import Text.Megaparsec.Char.Extra (eolOrEof)

space :: (MonadParsec e s m, Token s ~ Char) => m Char
space = single ' '

doubleSpace :: (MonadParsec e s m, Token s ~ Char) => m [Char]
doubleSpace = MP.count 2 space

commoditySymbol :: (MonadParsec e s m, Token s ~ Char) => m String
commoditySymbol = liftM2 (:) Char.letterChar (many alphaNumChar)

isCurrency :: String -> Bool
isCurrency = flip elem ["CHF", "USD", "PLN", "EUR"]

commodity :: MP.Parsec Void String Amount
commodity = do
  (maybeSymbol, amount) <-
    try
      ( do
          symbol <- commoditySymbol
          void $ some space
          amount <- decimalP defaultDecimalFormat
          return (Just symbol, amount)
      )
      <|> ( do
              amount <- decimalP defaultDecimalFormat
              symbol <- optional (some space >> commoditySymbol)
              return (symbol, amount)
          )
  void $ many space
  return $
    case maybeSymbol of
      Just symbol -> makeCommodityAmount symbol amount
      Nothing -> num amount

whenCurrencyAdjustStyle :: Amount -> Amount
whenCurrencyAdjustStyle amt
  | isCurrency (unpack $ acommodity amt) = setCurrencyPrecision amt
  | otherwise = amt

accountParser :: MP.Parsec Void String String
accountParser =
  someTill
    printChar
    ( try (doubleSpace >> many space)
        <|> try (optional space >> lookAhead eolOrEof)
    )

balanceAssertion :: MP.Parsec Void String BalanceAssertion
balanceAssertion = do
  void $ MP.single '=' >> some space
  fmap (fromJust . balassert . whenCurrencyAdjustStyle) commodity <* many space

statusParser :: (MonadParsec e s m, Token s ~ Char) => m Status
statusParser =
  choice
    [ try (single '*') $> Cleared
    , try (single '!') $> Pending
    , pure Unmarked
    ]

amountPriceParser :: MP.Parsec Void String AmountPrice
amountPriceParser = do
  constructor <-
    choice
      [ try (string "@@") $> TotalPrice
      , single '@' $> UnitPrice
      ]
  void $ some spaceChar
  constructor . setFullPrecision <$> commodity

-- | A partial Posting parser
postingParser :: MP.Parsec Void String Posting
postingParser = do
  status <- many space *> statusParser <* many space
  account <- accountParser
  amount <- whenCurrencyAdjustStyle <$> (try commodity <|> pure missingamt)
  balAssert <- optional (try balanceAssertion)
  void $ many $ single ' '
  amountPrice <- optional amountPriceParser
  let amount' =
        amount
          { aprice = amountPrice
          }
  void eolOrEof
  return $
    post (pack account) amount'
      & L.set pBalanceAssertion balAssert
        . L.set pStatus status

-- | A partial Transaction parser
--
-- This parser parses typical Transaction syntax.
-- It does not conform to the full Ledger spec.
transactionParser :: MP.Parsec Void String Transaction
transactionParser = do
  date <-
    manyTill MP.anySingle (some $ char ' ')
      >>= parseTimeM True defaultTimeLocale "%Y/%m/%d"
  status <- statusParser <* many space
  title <- manyTill anySingle (try newline)
  ps <- some postingParser
  return $
    Tr.transaction date ps
      & L.set tStatus status
        . L.set tDescription title

parseTransactionUnsafe :: String -> Transaction
parseTransactionUnsafe = fromJust . MP.parseMaybe transactionParser
