{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE OverloadedStrings #-}

module Test.Hledupt.Ib
  ( tests,
  )
where

import Hledger.Read.TestUtils (parseTransactionUnsafe)
import Hledupt.Ib
import Test.Hspec (describe, shouldBe)
import qualified Test.Hspec as Hspec

tests :: Hspec.SpecWith ()
tests = do
  describe "Hledupt.Ib" $ do
    parseTests

parseTests :: Hspec.SpecWith ()
parseTests = do
  describe "parse" $ do
    Hspec.it "parses a CSV" $ do
      let csv =
            "Statement,Header,Field Name,Field Value\n\
            \Statement,Data,BrokerName,Interactive Brokers\n\
            \Statement,Data,BrokerAddress,\n\
            \Statement,Data,Title,MTM Summary\n\
            \Statement,Data,Period,\"November 26, 2020\"\n\
            \Statement,Data,WhenGenerated,\"2020-11-28, 05:24:15 EST\"\n\
            \Account Information,Header,Field Name,Field Value\n\
            \Account Information,Data,Name,John Doe\n\
            \Positions and Mark-to-Market Profit and Loss,Header,Asset Class,Currency,Symbol,Description,Prior Quantity,Quantity,Prior Price,Price,Prior Market Value,Market Value,Position,Trading,Comm.,Other,Total\n\
            \Positions and Mark-to-Market Profit and Loss,Data,Stocks,USD,ACWF,ISHARES MSCI GLOBAL MULTIFAC,123,123,32.24,32.24,1001.01,1001.01,0,0,0,0,0\n\
            \Positions and Mark-to-Market Profit and Loss,Data,Total,USD,,,,,,,123,123,0,0,0,0,0\n\
            \Positions and Mark-to-Market Profit and Loss,Data,Forex,CHF,CHF, ,100.0011305,100.0011305,1,1,100.0011305,100.0011305,0,0,0,0,0"
      parseCsv csv
        `shouldBe` Right
          ( parseTransactionUnsafe
              "2020/11/26 IB Status\n\
              \  Assets:Investments:IB:ACWF  0 ACWF = ACWF 123\n\
              \  Assets:Liquid:IB:CHF  CHF 0 = CHF 100.0011305"
          )
