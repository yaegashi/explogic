library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

library UNISIM;
use UNISIM.vcomponents.ALL;

entity RAM16XYD is
  generic (Y: integer := 32);
  port (WE, WCLK: in std_logic;
  	A, DPRA: in std_logic_vector(3 downto 0);
	D: in std_logic_vector(Y-1 downto 0);
	SPO, DPO: out std_logic_vector(Y-1 downto 0));
end RAM16XYD;

architecture RTL of RAM16XYD is
begin

  RAM16XYD:
  for i in Y-1 downto 0 generate
  begin
    RAM0: RAM16X1D
    port map (
      WE => WE,
      WCLK => WCLK,
      A0 => A(0),
      A1 => A(1),
      A2 => A(2),
      A3 => A(3),
      DPRA0 => DPRA(0),
      DPRA1 => DPRA(1),
      DPRA2 => DPRA(2),
      DPRA3 => DPRA(3),
      D => D(i),
      SPO => SPO(i),
      DPO => DPO(i)
    );
  end generate;

end RTL;
