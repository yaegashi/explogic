-- $Id: crtc.vhd 28 2005-11-28 02:03:53Z yaegashi $

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

entity CRTC is
  generic (H0: integer := 640;
           H1: integer := 656;
	   H2: integer := 752;
	   H3: integer := 800;
	   V0: integer := 480;
	   V1: integer := 490;
	   V2: integer := 492;
	   V3: integer := 521);
  port (CLK, RESET: in std_logic;
        HSYNC, VSYNC, BLANK: out std_logic;
  	HADDR, VADDR, MADDR: out integer);
end CRTC;


architecture RTL of CRTC is

  signal CH: integer range 0 to H3-1;
  signal CV: integer range 0 to V3-1;
  signal CM: integer range 0 to H3*V3-1;
  signal IH, IV, BH, BV, BB: std_logic;

begin

  -- Managing CRTC counters
  process (RESET, CLK)
  begin
    if RESET = '1' then
      CH <= 0;
      CV <= 0;
    elsif CLK'event and CLK = '1' then
      if CH = H3-1 then
        CH <= 0;
        if CV = V3-1 then
	  CV <= 0;
        else
	  CV <= CV + 1;
	end if;
      else
        CH <= CH + 1;
      end if;
    end if;
  end process;

  -- Managing memory address
  process (RESET, CLK)
  begin
    if RESET = '1' then
      CM <= 0;
    elsif CLK'event and CLK = '1' then
      if CH = H3-1 and CV = V3-1 then
        CM <= 0;
      elsif BB = '0' then
        CM <= CM + 1;
      end if;
    end if;
  end process;

  -- Generating H/V sync signals and blanking flags
  process (RESET, CLK)
  begin
    if RESET = '1' then
      IH <= '1';
      IV <= '1';
      BH <= '0';
      BV <= '0';
    elsif CLK'event and CLK = '1' then
      if CH = H1-1 or CH = H2-1 then
        IH <= not IH;
      end if;
      if CH = H0-1 or CH = H3-1 then
        BH <= not BH;
      end if;
      if CH = H3-1 then
        if CV = V1-1 or CV = V2-1 then
	  IV <= not IV;
	end if;
	if CV = V0-1 or CV = V3-1 then
	  BV <= not BV;
	end if;
      end if;
    end if;
  end process;

  BB <= BH or BV;
  HADDR <= CH;
  VADDR <= CV;
  MADDR <= CM;
  HSYNC <= IH;
  VSYNC <= IV;
  BLANK <= BB;
  
end RTL;
