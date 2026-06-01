--------------------------------------------------------------------
--  _    __ __  __ ____   __   =                                  --
-- | |  / // / / // __ \ / /   =                                  --
-- | | / // /_/ // / / // /    =    .__  |/ _/_  .__   .__    __  --
-- | |/ // __  // /_/ // /___  =   /___) |  /   /   ) /   )  (_ ` --
-- |___//_/ /_//_____//_____/  =  (___  /| (_  /     (___(_ (__)  --
--                           =====     /                          --
--                            ===                                 --
-----------------------------  =  ----------------------------------
--# synchronizing.vhdl - Clock domain synchronization components
--# Freely available from VHDL-extras (http://github.com/kevinpt/vhdl-extras)
--#
--# Copyright � 2010 Kevin Thibedeau
--# (kevin 'period' thibedeau 'at' gmail 'punto' com)
--#
--# Permission is hereby granted, free of charge, to any person obtaining a
--# copy of this software and associated documentation files (the "Software"),
--# to deal in the Software without restriction, including without limitation
--# the rights to use, copy, modify, merge, publish, distribute, sublicense,
--# and/or sell copies of the Software, and to permit persons to whom the
--# Software is furnished to do so, subject to the following conditions:
--#
--# The above copyright notice and this permission notice shall be included in
--# all copies or substantial portions of the Software.
--#
--# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
--# DEALINGS IN THE SOFTWARE.
--#
--# DEPENDENCIES: none
--#
--# DESCRIPTION:
--#  This package provides a number of synchronizer components for managing
--#  data transmission between clock domains.
--#
--#  If you need to synchronize a vector of bits together you should use the
--#  handshake_synchronizer component. If you generate an array of bit_synchronizer
--#  components instead, there is a risk that some bits will take longer than
--#  others and invalid values will appear at the outputs. This is particularly
--#  problematic if the vector represents a numeric value. bit_synchronizer can
--#  be used safely in an array only if you know the input signal comes from an
--#  isochronous domain (same period, different phase).

--# SYNTHESIS:
--#  Vendor specific synthesis attributes have been included to help prevent
--#  undesirable results. It is important to know that, ideally, synchronizing
--#  flip-flops should be placed as close together as possible. It is also desirable
--#  to have the first stage flip-flop incorporated into the input buffer to minimize
--#  input delay. Because of this these components do not have attributes to guide
--#  relative placement of flip-flops to make them contiguous. Instead you should
--#  apply timing constraints to the components that will force the synthesizer into
--#  using an optimal placement.
--------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--## A basic synchronizer with a configurable number of stages
entity bit_synchronizer is
  generic (
    STAGES : natural := 2; --# Number of flip-flops in the synchronizer
    RESET_ACTIVE_LEVEL : std_logic := '1' --# Asynch. reset control level
  );
  port (
    Clock  : in std_logic; --# System clock
    Reset  : in std_logic; --# Asynchronous reset

    Bit_in : in std_logic; --# Unsynchronized signal
    Sync   : out std_logic --# Synchronized to Clock's domain
  );
end entity;

architecture rtl of bit_synchronizer is
  signal sr : std_logic_vector(1 to STAGES);
  
begin
  reg: process(Clock, Reset) is
  begin
    if Reset = RESET_ACTIVE_LEVEL then
      sr <= (others => '0');
    elsif rising_edge(Clock) then
      sr <= Bit_in & sr(1 to sr'right-1);
    end if;
  end process;

  Sync <= sr(sr'right);
end architecture;