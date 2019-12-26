----------------------------------------------------------------------------------
-- Company: University of Hong Kong ELEC3342
-- Engineer: Arthur Brock
-- 
-- Create Date: 12/09/2019 01:38:45 PM
-- Design Name: 
-- Module Name: mcencoder - Behavioral
-- Project Name: Final Assignment
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- First character after a space should not be an E.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity mcencoder is
  Port (clk : in std_logic;
        clr : in std_logic;
        din : in std_logic_vector(7 downto 0);
        den : in std_logic;
        sout : out std_logic);
--        testfifo: out std_logic_vector(7 downto 0);
  --      ren : out std_logic;
    --    FSM2SOUT : out std_logic_vector(14 downto 0);
      --  lengthout : out integer;
        --lengthcounterout : out integer;
        --shiftout : out std_logic_vector(14 downto 0));
end mcencoder;

architecture Behavioral of mcencoder is
--FIFO
signal read_index : unsigned(3 downto 0);
signal read_enable : boolean;
signal write_index : unsigned(3 downto 0);
signal written_counter : unsigned(3 downto 0);

type FIFO is array(0 to 15) of std_logic_vector(7 downto 0);
signal FIFO_m : FIFO;

signal full : boolean;
signal empty : boolean;
signal periodsblessing : boolean;

signal FIFO2FSM : std_logic_vector(7 downto 0);

--FSM
type state_type is (A, A0, B, B0, C, C0, D, D0, E, E0, F, F0, space, idle, period, period0);
signal state, next_state : state_type;

signal length : integer;
signal FSM2SOUT : std_logic_vector(14 downto 0);

--UART
signal waitonelength : boolean;
signal length_counter : integer;

begin
--FIFO
--handling read enable
--ren <= read_enable;
process(clk, length_counter, periodsblessing, empty, length)
begin

--if it gets full or mainly if din is a period
--this will later be modified to go high for when the serial is outputing
    if rising_edge(clk) then
        if ((not empty) and (length_counter = length - 3) and periodsblessing) then
            read_enable <= true;
        else
            read_enable <= false;
        end if;
    end if;
end process;

--waitonelength flag decider
process(clk, length_counter, periodsblessing)
begin
    if rising_edge(clk) then
        if periodsblessing and length_counter = length - 1 then
            waitonelength <= true;
        elsif (not periodsblessing) and waitonelength and (length_counter <= length - 2 or den = '1') then
            waitonelength <= false;
        else
            waitonelength <= waitonelength;
        end if;
    end if;
end process;

--periods blessing flag decider
process(clk, din, den, empty)
begin
if rising_edge(clk) then
    if (not empty) and din = x"2E" and den = '1' then
        periodsblessing <= true;
    elsif empty and periodsblessing and length_counter = length - 2 then
        periodsblessing <= false;
    else
        periodsblessing <= periodsblessing;
    end if;
end if;
end process;

--index incrementer
indexincrement : process(clk, clr, den, full, read_enable)
begin
    case clr is
        when '1' =>
            read_index <= "0000";
            write_index <= "0000";
        when others =>
            if rising_edge(clk) then
                if den = '1' and (not full) then
                    write_index <= write_index + 1;
                end if;
                if read_enable then
                    read_index <= read_index + 1;
                end if;
            end if;
    end case;
end process;

--head/tail
process(clk, clr, din, write_index, read_index)
begin
    case clr is
        when '1' =>
            for k in 0 to 7 loop
                FIFO_m(k) <= "00000000";
            end loop;
        when others =>
            if rising_edge(clk) then
                FIFO_m(to_integer(write_index)) <= din;
                if (length_counter = 0) then
                    FIFO2FSM <= FIFO_m(to_integer(read_index));
--                    testfifo <= FIFO_m(to_integer(read_index));
                end if;
            end if;  
    end case;
end process;

--written counter
process(write_index, read_index)
begin
    if write_index < read_index then
        written_counter <= write_index - read_index + 16;
    else
        written_counter <= write_index - read_index;
    end if;
end process;

--full and empty signals
empty <= true when written_counter = 0 else false;
full <= true when written_counter = 15 else false;

--FSM
--moore machine
--state registers it also gives output sout
state_registers : process(clk, clr, next_state, state)
begin
    case clr is
        when '1' =>
            state <= idle;
            sout <= '0';
        when others =>
            if rising_edge(clk) then
                if waitonelength then
                    sout <= FSM2SOUT(length_counter);
                end if;
                if periodsblessing then
                    state <= next_state;
                end if;
--                FSM2SOUTout <= FSM2SOUT;
  --              lengthout <= length;
            else
                state <= state;
            end if;
    end case;
end process;

--output logic
outputLogic : process(state, clk)
begin
    case state is
        when idle =>
            length <= 0;
            FSM2SOUT <= "000000000000000";
        when A =>
            length <= 5;
            FSM2SOUT <= "000000000011101";
        when B =>
            length <= 9;
            FSM2SOUT <= "000000101010111";
        when C =>
            length <= 11;
            FSM2SOUT <= "000010111010111";
        when D =>
            length <= 7;
            FSM2SOUT <= "000000001010111";
        when E =>
            length <= 1;
            FSM2SOUT <= "000000000000001";
        when F =>
            length <= 9;
            FSM2SOUT <= "000000101110101";
        when period =>
            length <= 11;
            FSM2SOUT <= "000011101011101";
        when space =>
            length <= 7;
            FSM2SOUT <= "000000000000000";
        when A0 =>
            length <= 8;
            FSM2SOUT <= "000000011101000";
        when B0 =>
            length <= 12;
            FSM2SOUT <= "000101010111000";
        when C0 =>
            length <= 14;
            FSM2SOUT <= "010111010111000";
        when D0 =>
            length <= 10;
            FSM2SOUT <= "000001010111000";
        when E0 =>
            length <= 4;
            FSM2SOUT <= "000000000001000";
        when F0 =>
            length <= 12;
            FSM2SOUT <= "000101110101000";
        when period0 =>
            length <= 14;
            FSM2SOUT <= "011101011101000";
    end case;
end process;

--next_state logic
process(state, FIFO2FSM, clk)
begin
if rising_edge(clk) and ((length_counter = length - 2) and periodsblessing) then
    case state is
        when A =>
            if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
            elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when B =>
        if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
            elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when C =>
        if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
            elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when D =>
        if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
            elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when E =>
            if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
             elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when F =>
        if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
            elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when space =>
            if FIFO2FSM = x"41" then
                next_state <= A;
            elsif FIFO2FSM = x"42" then
                next_state <= B;
            elsif FIFO2FSM = x"43" then
                next_state <= C;
            elsif FIFO2FSM = x"44" then
                next_state <= D;
            elsif FIFO2FSM = x"45" then
                next_state <= E;
            elsif FIFO2FSM = x"46" then
                next_state <= F;
            elsif FIFO2FSM = x"2E" then
                next_state <= period;
            elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when idle =>
            if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
            elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when A0 =>
        if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
             elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when B0 =>
        if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
             elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when C0 =>
        if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
            elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when D0 =>
        if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
             elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when E0 =>
            if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
             elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when F0 =>
            if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
             elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
        when others =>
            if FIFO2FSM = x"41" then
                next_state <= A0;
            elsif FIFO2FSM = x"42" then
                next_state <= B0;
            elsif FIFO2FSM = x"43" then
                next_state <= C0;
            elsif FIFO2FSM = x"44" then
                next_state <= D0;
            elsif FIFO2FSM = x"45" then
                next_state <= E0;
            elsif FIFO2FSM = x"46" then
                next_state <= F0;
            elsif FIFO2FSM = x"2E" then
                next_state <= period0;
             elsif FIFO2FSM = x"20" then
                next_state <= space;
            else
                next_state <= idle;
            end if;
    end case;
end if;
end process;

--this counts for the of a characters morse code
lengthcounter : process(clk, clr, length, length_counter, empty)
begin
    case clr is
        when '1' =>
            length_counter <= 0;
        when others =>
            if rising_edge(clk) then
--                lengthcounterout <= length_counter;
                if length_counter = length - 1 then
                    length_counter <= 0;
                elsif length_counter < length - 1 and periodsblessing then
                    length_counter <= length_counter + 1;
                else
                    length_counter <= length_counter;
                end if;
            end if;
    end case;
end process;

end Behavioral;
