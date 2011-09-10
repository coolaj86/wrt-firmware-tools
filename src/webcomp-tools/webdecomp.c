/*
 * Extracts the embedded Web GUI files from DD-WRT file systems.
 *
 * Craig Heffner
 * 07 September 2011
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <getopt.h>
#include "common.h"
#include "webdecomp.h"

int main(int argc, char *argv[])
{
	char *httpd = NULL, *www = NULL, *dir = NULL;
	int retval = EXIT_FAILURE, action = NONE, long_opt_index = 0, n = 0;
	char c = 0;

	char *short_options = "b:w:d:erh";
	struct option long_options[] = {
		{ "httpd", required_argument, NULL, 'b' },
		{ "www", required_argument, NULL, 'w' },
		{ "dir", required_argument, NULL, 'd' },
		{ "extract", no_argument, NULL, 'e' },
		{ "restore", no_argument, NULL, 'r' },
		{ "help", no_argument, NULL, 'h' },
		{ 0, 0, 0, 0 }
	};
	
	while((c = getopt_long(argc, argv, short_options, long_options, &long_opt_index)) != -1)
	{
		switch(c)
		{
			case 'b':
				httpd = strdup(optarg);
				break;
			case 'w':
				www = strdup(optarg);
				break;
			case 'd':
				dir = strdup(optarg);
				break;
			case 'e':
				action = EXTRACT;
				break;
			case 'r':
				action = RESTORE;
				break;
			default:
				usage(argv[0]);
				goto end;
			
		}
	}

	/* Verify that all required options were specified  */
	if(action == NONE || httpd == NULL || www == NULL)
	{
		usage(argv[0]);
		goto end;
	}

	/* If no output directory was specified, use the default (www) */
	if(!dir)
	{
		dir = strdup(DEFAULT_OUTDIR);
	}

	/* Extract! */
	if(action == EXTRACT)
	{
		n = extract(httpd, www, dir);
	}
	/* Restore! */
	else if(action == RESTORE)
	{
		n = restore(httpd, www, dir);
	}

	if(n > 0)
	{
		printf("\nProcessed %d Web files.\n\n", n);
		retval = EXIT_SUCCESS;
	}
	else
	{
		fprintf(stderr, "Failed to process Web files!\n");
	}

end:
	if(httpd) free(httpd);
	if(www) free(www);
	if(dir) free(dir);
	return retval;
}

/* Extract embedded file contents from binary file(s) */
int extract(char *httpd, char *www, char *outdir)
{
	int n = 0;
	size_t hsize = 0, wsize = 0;
	struct entry_info *info = NULL;
	unsigned char *hdata = NULL, *wdata = NULL;
	char *dir_tmp = NULL, *path = NULL;

	/* Read in the httpd and www files */
	hdata = (unsigned char *) file_read(httpd, &hsize);
	wdata = (unsigned char *) file_read(www, &wsize);
	
	if(hdata != NULL && wdata != NULL && find_websRomPageIndex(httpd) && parse_elf_header(hdata, hsize))
	{
		/* Create the output directory, if it doesn't already exist */
		mkdir_p(outdir);

		/* Change directories to the output directory */
        	if(chdir(outdir) == -1)
        	{
                	perror(outdir);
        	}
		else 
		{
			/* Get the next entry until we get a blank entry */
			while((info = next_entry(hdata, hsize)) != NULL)
			{
				/* Make sure the full file path is safe (i.e., it won't overwrite something critical on the host system) */
				path = make_path_safe(info->name);
				if(path)
				{
					/* Display the file name */
					printf("%s\n", info->name);
					
					/* dirname() clobbers the string you pass it, so make a temporary one */
					dir_tmp = strdup(path);
					mkdir_p(dirname(dir_tmp));
					free(dir_tmp);

					/* Write the data to disk */
					if(!file_write(path, (wdata + info->entry->offset), info->entry->size))
					{
						fprintf(stderr, "ERROR: Failed to extract file '%s'\n", info->name);
					}
					else
					{
						n++;
					}

					free(path);
				}
				else
				{
					fprintf(stderr, "File path '%s' is not safe! Skipping...\n", info->name);
				}

				free(info);
			}
		}
	}
	else
	{
		printf("Failed to parse ELF header!\n");
	}
	
	if(hdata) free(hdata);
	if(wdata) free(wdata);
	return n;
}

/* Restore embedded file contents to binary file(s) */
int restore(char *httpd, char *www, char *indir)
{
	int n = 0, total = 0;
	FILE *fp = NULL;
	size_t hsize = 0, fsize = 0;
	struct entry_info *info = NULL;
	unsigned char *hdata = NULL, *fdata = NULL;
	char origdir[FILENAME_MAX] = { 0 };
	char *path = NULL;

	/* Read in the httpd file */
	hdata = (unsigned char *) file_read(httpd, &hsize);
	
	/* Get the current working directory */
	getcwd((char *) &origdir, sizeof(origdir));

	/* Open the www file for writing */
	fp = fopen(www, "wb");

	if(hdata != NULL && fp != NULL && find_websRomPageIndex(httpd) && parse_elf_header(hdata, hsize))
	{
		/* Change directories to the target directory */
        	if(chdir(indir) == -1)
        	{
                	perror(indir);
        	}
		else 
		{
			/* Get the next entry until we get a blank entry */
			while((info = next_entry(hdata, hsize)) != NULL)
			{
				/* Count the number of files we process */
				n++;
			
				/* Make sure the full file path is safe (i.e., it won't overwrite something critical on the host system) */
				path = make_path_safe(info->name);
				if(path)
				{
					/* Display the file name */
					printf("%s\n", info->name);

					/* Read in the file */
					fdata = (unsigned char *) file_read(path, &fsize);
				
					/* Update the entry size and file offset */
                                        info->entry->size = fsize;
                                        info->entry->offset = total;
					hton_struct(info->entry);
	
					/* Write the new file to the www blob file */
					if(fdata)
					{
						if(fwrite(fdata, 1, fsize, fp) != fsize)
						{
							fprintf(stderr, "ERROR: Failed to restore file '%s'\n", info->name);
						}
						else
						{
							/* Update the total size written to the www blob */
							total += fsize;
						}
	
						free(fdata);
					}
	
					free(path);
				}
				else
				{
					fprintf(stderr, "File path '%s' is not safe! Skipping...\n", info->name);
				}
		
				free(info);
			}

			/* The www blob file always appears to be null byte terminated */
			fwrite("\x00", 1, 1, fp);

			/* Change back to our original directory, so that relative paths for httpd will still work */
			if(chdir((char *) &origdir) != -1)
			{
				/* Write the modified httpd binary back to disk */
				file_write(httpd, hdata, hsize);
			}
			else
			{
				perror(origdir);
			}
		}
	}
	else
	{
		printf("Failed to parse ELF header!\n");
	}
	
	if(fp) fclose(fp);
	if(hdata) free(hdata);
	return n;
}

void usage(char *progname)
{
	fprintf(stderr, "\n");
	fprintf(stderr, USAGE, progname, DEFAULT_OUTDIR);
	fprintf(stderr, "\n");

	return;
}
