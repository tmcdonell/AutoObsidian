{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Fractals

import Prelude hiding (replicate, writeFile)
import Prelude as P

import Obsidian
import Obsidian.Run.CUDA.Exec

import qualified Data.Vector.Storable as V
import Control.Monad.State

import Data.Int

import Data.ByteString as BS hiding (putStrLn, length)

import System.Environment
import System.CPUTime.Rdtsc
import System.Exit

import Data.Time.Clock
import Control.DeepSeq

-- Autotuning framework 
import Auto.Score

-- timing
import Criterion.Main
import Criterion.Types 


threads = 256
image_size = 1024
identity = 256

-- Vary number of threads/block and image size  
main = do
  putStrLn "Autotuning Mandelbrot fractal kernel"

  ctx <- initialise

  
  kern <- captureIO ("kernel" ++ show identity)
          (props ctx)
          threads
          (mandel image_size)
  
  
  
  
  withCUDA' ctx $
    do    
      transfer_start <- lift getCurrentTime
      allocaVector (fromIntegral (s*s)) $ \o -> 
        do
          transfer_done <- lift getCurrentTime 
          
          t0   <- lift getCurrentTime
          cnt0 <- lift rdtsc
          forM_ [0..999] $ \_ -> do
            o <== (s,kern)
            syncAll
          cnt1 <- lift rdtsc
          t1   <- lift getCurrentTime
          
          r <- copyOut o 
          t_end <- lift getCurrentTime
  
          -- Still going via list !!! 
          lift $ BS.writeFile "fractal.out" (pack (V.toList r))

          lift $ putStrLn $ "SELFTIMED: " ++ show (diffUTCTime t1 t0)
          lift $ putStrLn $ "CYCLES: "    ++ show (cnt1 - cnt0)

          lift $ putStrLn $ "COMPILATION_TIME: " ++ show (diffUTCTime compile_t1 compile_t0)
    
          lift $ putStrLn $ "BYTES_TO_DEVICE: " ++ show 0
          lift $ putStrLn $ "BYTES_FROM_DEVICE: " ++ show (fromIntegral (s*s))
          lift $ putStrLn $ "TRANSFER_TO_DEVICE: " ++ show (diffUTCTime transfer_done transfer_start)
          lift $ putStrLn $ "TRANSFER_FROM_DEVICE: " ++ show (diffUTCTime t_end t1)

          -- in this case computed
          lift $ putStrLn $ "ELEMENTS_PROCESSED: " ++ show (fromIntegral (s*s))
          lift $ putStrLn $ "NUMBER_OF_BLOCKS: "   ++ show (fromIntegral s)
          lift $ putStrLn $ "ELEMENTS_PER_BLOCK: " ++ show s 
          
