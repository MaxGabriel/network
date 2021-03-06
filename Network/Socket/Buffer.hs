{-# LANGUAGE CPP #-}
{-# LANGUAGE RecordWildCards #-}

#include "HsNetDef.h"

module Network.Socket.Buffer (
    sendBufTo
  , sendBuf
  , recvBufFrom
  , recvBuf
  ) where

import Data.Word (Word8)
import Foreign.C.Types (CInt(..), CSize(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (Storable(..))
import System.IO.Error (mkIOError, ioeSetErrorString)
import GHC.IO.Exception (IOErrorType(EOF, InvalidArgument))

#if defined(mingw32_HOST_OS)
import GHC.IO.FD (FD(..), readRawBufferPtr, writeRawBufferPtr)
#else
import Foreign.C.Types (CChar)
#endif

import Network.Socket.Internal
import Network.Socket.Name
import Network.Socket.Types

-- | Send data to the socket.  The recipient can be specified
-- explicitly, so the socket need not be in a connected state.
-- Returns the number of bytes sent.  Applications are responsible for
-- ensuring that all data has been sent.
sendBufTo :: Socket            -- (possibly) bound/connected Socket
          -> Ptr a -> Int  -- Data to send
          -> SockAddr
          -> IO Int            -- Number of Bytes sent
sendBufTo sock@Socket{..} ptr nbytes addr =
 withSockAddr addr $ \p_addr sz ->
   fmap fromIntegral $
     throwSocketErrorWaitWrite sock "Network.Socket.sendBufTo" $
        c_sendto socketFd ptr (fromIntegral nbytes) 0{-flags-}
                        p_addr (fromIntegral sz)

#if defined(mingw32_HOST_OS)
socket2FD :: Socket -> FD
socket2FD Socket{..} =
  -- HACK, 1 means True
  FD{ fdFD = socketFd, fdIsSocket_ = 1 }
#endif

-- | Send data to the socket. The socket must be connected to a remote
-- socket. Returns the number of bytes sent.  Applications are
-- responsible for ensuring that all data has been sent.
--
-- Sending data to closed socket may lead to undefined behaviour.
sendBuf :: Socket     -- Bound/Connected Socket
        -> Ptr Word8  -- Pointer to the data to send
        -> Int        -- Length of the buffer
        -> IO Int     -- Number of Bytes sent
sendBuf sock str len =
   fmap fromIntegral $
#if defined(mingw32_HOST_OS)
-- writeRawBufferPtr is supposed to handle checking for errors, but it's broken
-- on x86_64 because of GHC bug #12010 so we duplicate the check here. The call
-- to throwSocketErrorIfMinus1Retry can be removed when no GHC version with the
-- bug is supported.
    throwSocketErrorIfMinus1Retry "Network.Socket.sendBuf" $ writeRawBufferPtr
      "Network.Socket.sendBuf"
      (socket2FD sock)
      (castPtr str)
      0
      (fromIntegral len)
#else
     throwSocketErrorWaitWrite sock "Network.Socket.sendBuf" $
        c_send (socketFd sock) str (fromIntegral len) 0{-flags-}
#endif

-- | Receive data from the socket, writing it into buffer instead of
-- creating a new string.  The socket need not be in a connected
-- state. Returns @(nbytes, address)@ where @nbytes@ is the number of
-- bytes received and @address@ is a 'SockAddr' representing the
-- address of the sending socket.
--
-- NOTE: blocking on Windows unless you compile with -threaded (see
-- GHC ticket #1129)
recvBufFrom :: Socket -> Ptr a -> Int -> IO (Int, SockAddr)
recvBufFrom sock@Socket{..} ptr nbytes
 | nbytes <= 0 = ioError (mkInvalidRecvArgError "Network.Socket.recvBufFrom")
 | otherwise   =
    withNewSockAddr socketFamily $ \ptr_addr sz ->
      alloca $ \ptr_len -> do
        poke ptr_len (fromIntegral sz)
        len <- throwSocketErrorWaitRead sock "Network.Socket.recvBufFrom" $
                   c_recvfrom socketFd ptr (fromIntegral nbytes) 0{-flags-}
                                ptr_addr ptr_len
        let len' = fromIntegral len
        if len' == 0
         then ioError (mkEOFError "Network.Socket.recvFrom")
         else do
           flg <- isConnected sock
             -- For at least one implementation (WinSock 2), recvfrom() ignores
             -- filling in the sockaddr for connected TCP sockets. Cope with
             -- this by using getPeerName instead.
           sockaddr <-
                if flg then
                   getPeerName sock
                else
                   peekSockAddr ptr_addr
           return (len', sockaddr)

-- | Receive data from the socket.  The socket must be in a connected
-- state. This function may return fewer bytes than specified.  If the
-- message is longer than the specified length, it may be discarded
-- depending on the type of socket.  This function may block until a
-- message arrives.
--
-- Considering hardware and network realities, the maximum number of
-- bytes to receive should be a small power of 2, e.g., 4096.
--
-- For TCP sockets, a zero length return value means the peer has
-- closed its half side of the connection.
--
-- Receiving data from closed socket may lead to undefined behaviour.
recvBuf :: Socket -> Ptr Word8 -> Int -> IO Int
recvBuf sock ptr nbytes
 | nbytes <= 0 = ioError (mkInvalidRecvArgError "Network.Socket.recvBuf")
 | otherwise   = do
        len <-
#if defined(mingw32_HOST_OS)
-- see comment in sendBuf above.
            throwSocketErrorIfMinus1Retry "Network.Socket.recvBuf" $
                readRawBufferPtr "Network.Socket.recvBuf"
                (socket2FD sock) ptr 0 (fromIntegral nbytes)
#else
               throwSocketErrorWaitRead sock "Network.Socket.recvBuf" $
                   c_recv (socketFd sock) (castPtr ptr) (fromIntegral nbytes) 0{-flags-}
#endif
        let len' = fromIntegral len
        if len' == 0
         then ioError (mkEOFError "Network.Socket.recvBuf")
         else return len'

mkInvalidRecvArgError :: String -> IOError
mkInvalidRecvArgError loc = ioeSetErrorString (mkIOError
                                    InvalidArgument
                                    loc Nothing Nothing) "non-positive length"

mkEOFError :: String -> IOError
mkEOFError loc = ioeSetErrorString (mkIOError EOF loc Nothing Nothing) "end of file"

#if !defined(mingw32_HOST_OS)
foreign import CALLCONV unsafe "send"
  c_send :: CInt -> Ptr a -> CSize -> CInt -> IO CInt
foreign import CALLCONV unsafe "recv"
  c_recv :: CInt -> Ptr CChar -> CSize -> CInt -> IO CInt
#endif
foreign import CALLCONV SAFE_ON_WIN "sendto"
  c_sendto :: CInt -> Ptr a -> CSize -> CInt -> Ptr SockAddr -> CInt -> IO CInt
foreign import CALLCONV SAFE_ON_WIN "recvfrom"
  c_recvfrom :: CInt -> Ptr a -> CSize -> CInt -> Ptr SockAddr -> Ptr CInt -> IO CInt
