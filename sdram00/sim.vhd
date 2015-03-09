-- $Id: tsim.vhd 49 2005-11-29 13:29:05Z yaegashi $
-- vim: set sw=2 sts=2:

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.std_logic_arith.ALL;

entity sim is end;

architecture behavior of sim is

  component TOP
    port (
      CLK: in std_logic;
      SD_A: out std_logic_vector(12 downto 0);
      SD_DQ: inout std_logic_vector(15 downto 0);
      SD_BA: out std_logic_vector(1 downto 0);
      SD_RAS, SD_CAS, SD_WE, SD_CK_N, SD_CK_P, SD_CKE, SD_CS: out std_logic;
      SD_LDM, SD_UDM: out std_logic;
      SD_LDQS, SD_UDQS: inout std_logic;
      VR, VG, VB, VH, VV: out std_logic
    );
  end component;

  component ddr
    port (
      Clk, Clk_n, Cke, Cs_n, Ras_n, Cas_n, We_n: in std_logic;
      Ba: in std_logic_vector(1 downto 0);
      Addr: in std_logic_vector(12 downto 0);
      Dm: in std_logic_vector(1 downto 0);
      Dq: inout std_logic_vector(15 downto 0);
      Dqs: inout std_logic_vector(1 downto 0)
    );
  end component;
  
  signal CLK: std_logic;
  signal SD_A: std_logic_vector(12 downto 0);
  signal SD_DQ: std_logic_vector(15 downto 0);
  signal SD_BA: std_logic_vector(1 downto 0);
  signal SD_RAS, SD_CAS, SD_WE, SD_CK_N, SD_CK_P, SD_CKE, SD_CS: std_logic;
  signal SD_LDM, SD_UDM, SD_LDQS, SD_UDQS: std_logic;
  signal VR, VG, VB, VH, VV: std_logic;

  constant CYCLE: Time := 20 ns;
  
begin

  U0: TOP
  port map (
    CLK => CLK,
    SD_A => SD_A,
    SD_DQ => SD_DQ,
    SD_BA => SD_BA,
    SD_RAS => SD_RAS,
    SD_CAS => SD_CAS,
    SD_WE => SD_WE,
    SD_CK_N => SD_CK_N,
    SD_CK_P => SD_CK_P,
    SD_CKE => SD_CKE,
    SD_CS => SD_CS,
    SD_LDM => SD_LDM,
    SD_UDM => SD_UDM,
    SD_LDQS => SD_LDQS,
    SD_UDQS => SD_UDQS,
    VR => VR,
    VG => VG,
    VB => VB,
    VH => VH,
    VV => VV
  );

  U1: ddr
  port map(
    Clk => SD_CK_P,
    Clk_n => SD_CK_N,
    Cke => SD_CKE,
    Cs_n => SD_CS,
    Ras_n => SD_RAS,
    Cas_n => SD_CAS,
    We_n => SD_WE,
    Ba => SD_BA,
    Addr => SD_A,
    Dm(0) => SD_LDM,
    Dm(1) => SD_UDM,
    Dq => SD_DQ,
    Dqs(0) => SD_LDQS,
    Dqs(1) => SD_UDQS
  );

  process
  begin
    CLK <= '1';
    wait for CYCLE/2;
    CLK <= '0';
    wait for CYCLE/2;
  end process;
  
end behavior;
