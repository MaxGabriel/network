#include "HsNet.h"
##include "HsNetDef.h"
{-# OPTIONS_GHC -fno-warn-deprecations #-}

module Network.Socket.Constant where

import Network.Socket.Types

-- ---------------------------------------------------------------------------
-- Utility Functions

{-# DEPRECATED aNY_PORT "Use getAddrInfo instead" #-}
aNY_PORT :: PortNumber
aNY_PORT = 0

{-# DEPRECATED iNADDR_ANY "Use getAddrInfo instead" #-}
-- | The IPv4 wild card address.
iNADDR_ANY :: HostAddress
iNADDR_ANY = htonl (#const INADDR_ANY)

{-# DEPRECATED iN6ADDR_ANY "Use getAddrInfo instead" #-}
-- | The IPv6 wild card address.
iN6ADDR_ANY :: HostAddress6
iN6ADDR_ANY = (0, 0, 0, 0)

{-# DEPRECATED sOMAXCONN "Use maxListenQueue instead" #-}
sOMAXCONN :: Int
sOMAXCONN = #const SOMAXCONN

-- | This is the value of SOMAXCONN, typically 128.
-- 128 is good enough for normal network servers but
-- is too small for high performance servers.
maxListenQueue :: Int
maxListenQueue = sOMAXCONN
