--  Test program. Read a valid toml-test compatible JSON description on the
--  standard input and emit a corresponding TOML document on the standard
--  output.

with Ada.Containers.Generic_Array_Sort;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNATCOLL.JSON;

with TOML;
with TOML.Generic_Dump;

procedure Ada_TOML_Encode is

   use type Ada.Strings.Unbounded.Unbounded_String;
   use all type GNATCOLL.JSON.JSON_Value_Type;

   package US renames Ada.Strings.Unbounded;
   package IO renames Ada.Text_IO;
   package J renames GNATCOLL.JSON;

   type Stdout_Stream is null record;

   procedure Put (Stream : in out Stdout_Stream; Bytes : String);
   --  Callback for TOML.Generic_Dump

   function Interpret (Desc : J.JSON_Value) return TOML.TOML_Value;
   --  Interpret the given toml-test compatible JSON description (Value) and
   --  return the corresponding TOML value.

   type String_Array is array (Positive range <>) of US.Unbounded_String;

   procedure Sort_Strings is new Ada.Containers.Generic_Array_Sort
     (Index_Type   => Positive,
      Element_Type => US.Unbounded_String,
      Array_Type   => String_Array,
      "<"          => US."<");

   function Sorted_Keys (Desc : J.JSON_Value) return String_Array
      with Pre => Desc.Kind = JSON_Object_Type;
   --  Return a sorted array for all keys in the Desc object

   ---------
   -- Put --
   ---------

   procedure Put (Stream : in out Stdout_Stream; Bytes : String) is
      pragma Unreferenced (Stream);
   begin
      IO.Put (Bytes);
   end Put;

   -----------------
   -- Sorted_Keys --
   -----------------

   function Sorted_Keys (Desc : J.JSON_Value) return String_Array is
      Count : Natural := 0;

      procedure Count_CB
        (Dummy_Name : J.UTF8_String; Dummy_Value : J.JSON_Value);

      --------------
      -- Count_CB --
      --------------

      procedure Count_CB
        (Dummy_Name : J.UTF8_String; Dummy_Value : J.JSON_Value) is
      begin
         Count := Count + 1;
      end Count_CB;
   begin
      Desc.Map_JSON_Object (Count_CB'Access);

      return Result : String_Array (1 .. Count) do
         declare
            I : Positive := Result'First;

            procedure Read_Entry
              (Name : J.UTF8_String; Dummy_Value : J.JSON_Value);

            ----------------
            -- Read_Entry --
            ----------------

            procedure Read_Entry
              (Name : J.UTF8_String; Dummy_Value : J.JSON_Value) is
            begin
               Result (I) := US.To_Unbounded_String (Name);
               I := I + 1;
            end Read_Entry;
         begin
            Desc.Map_JSON_Object (Read_Entry'Access);
            Sort_Strings (Result);
         end;
      end return;
   end Sorted_Keys;

   ---------------
   -- Interpret --
   ---------------

   function Interpret (Desc : J.JSON_Value) return TOML.TOML_Value is
      Result : TOML.TOML_Value;
   begin
      case Desc.Kind is
         when JSON_Object_Type =>
            declare
               Keys : constant String_Array := Sorted_Keys (Desc);
            begin
               if Keys'Length = 2
                  and then Keys (1) = US.To_Unbounded_String ("type")
                  and then Keys (2) = US.To_Unbounded_String ("value")
               then
                  declare
                     T : constant String := Desc.Get ("type");
                     V : constant J.JSON_Value := Desc.Get ("value");
                  begin
                     if T = "string" then
                        declare
                           S : constant String := V.Get;
                        begin
                           Result := TOML.Create_String (S);
                        end;

                     elsif T = "integer" then
                        declare
                           S : constant String := V.Get;
                        begin
                           Result :=
                              TOML.Create_Integer (TOML.Any_Integer'Value (S));
                        end;

                     elsif T = "bool" then
                        declare
                           S : constant String := V.Get;
                        begin
                           Result := TOML.Create_Boolean (Boolean'Value (S));
                        end;

                     elsif T = "array" then
                        Result := Interpret (V);

                     else
                        raise Program_Error with "unhandled value type: " & T;
                     end if;
                  end;

               else
                  Result := TOML.Create_Table;
                  for K of Keys loop
                     declare
                        Item : constant TOML.TOML_Value :=
                           Interpret (Desc.Get (US.To_String (K)));
                     begin
                        Result.Set (K, Item);
                     end;
                  end loop;
               end if;
            end;

         when JSON_Array_Type =>
            declare
               Elements : constant J.JSON_Array := Desc.Get;
            begin
               Result := TOML.Create_Array;
               for I in 1 .. J.Length (Elements) loop
                  Result.Append (Interpret (J.Get (Elements, I)));
               end loop;
            end;

         when others =>
            raise Program_Error;
      end case;

      return Result;
   end Interpret;

   procedure Dump is new TOML.Generic_Dump (Stdout_Stream, Put);

   Input       : US.Unbounded_String;
   Description : J.JSON_Value;
   Result      : TOML.TOML_Value;
   Stdout      : Stdout_Stream := (null record);
begin
   --  Read the stdin until end of file and store its content in Input

   loop
      begin
         declare
            Line : constant String := IO.Get_Line;
         begin
            US.Append (Input, Line);
         end;
      exception
         when IO.End_Error =>
            exit;
      end;
   end loop;

   --  Decode this input as JSON

   Description := J.Read (US.To_String (Input));

   --  Build the TOML document from the JSON description and output it on the
   --  standard output.

   Result := Interpret (Description);
   Dump (Stdout, Result);
end Ada_TOML_Encode;